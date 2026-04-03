import Carbon

/// Manages and dispatches window management events.
/// Processes events serially on the main queue so AppKit, AX callbacks, and
/// window/application state all stay on the same thread.
final class EventManager {
  static let shared = EventManager()

  private let queue = OperationQueue.main
  private let accessibilityQueue = DispatchQueue(
    label: "dev.tombell.Stark.EventManager.accessibility",
    qos: .userInitiated
  )

  private let applicationHandler = ApplicationLifecycleHandler()
  private let windowHandler = WindowLifecycleHandler()
  private let spaceHandler = SpaceLifecycleHandler()

  /// Posts a typed runtime event to be processed asynchronously.
  func post(_ event: RuntimeEvent) {
    queue.addOperation { self.handle(event) }
  }

  /// Resolves a window identifier off the main run loop before dispatching the event.
  /// This keeps AX observer callbacks lightweight and avoids blocking the app on
  /// `_AXUIElementGetWindow` when the target process is slow to respond.
  func post(windowIdentifierEvent event: WindowIdentifierEvent, withWindowElement element: AXUIElement) {
    accessibilityQueue.async {
      let windowID = Window.id(for: element)
      self.post(.window(event.runtimeEvent(windowID: windowID)))
    }
  }

  private func handle(_ event: RuntimeEvent) {
    switch event {
    case .application(let event):
      applicationHandler.handle(event)
    case .window(let event):
      windowHandler.handle(event)
    case .space(let event):
      spaceHandler.handle(event)
    }
  }
}

enum WindowIdentifierEvent {
  case focused
  case moved
  case resized

  func runtimeEvent(windowID: CGWindowID) -> WindowEvent {
    switch self {
    case .focused:
      .focused(windowID)
    case .moved:
      .moved(windowID)
    case .resized:
      .resized(windowID)
    }
  }
}

private struct ApplicationLifecycleHandler {
  func handle(_ event: ApplicationEvent) {
    switch event {
    case .launched(let process):
      applicationLaunched(for: process)
    case .terminated(let process):
      applicationTerminated(for: process)
    case .frontSwitched(let process):
      applicationFrontSwitched(for: process)
    }
  }

  private func applicationLaunched(for process: Process) {
    if process.terminated {
      log("application terminated during launch \(process)")
      return
    }

    if !Workspace.shared.isFinishedLaunching(process) {
      log("application has not finished launching \(process)")
      Workspace.shared.observeFinishedLaunching(process)

      guard Workspace.shared.isFinishedLaunching(process) else { return }
      Workspace.shared.unobserveFinishedLaunching(process)
    }

    if !Workspace.shared.isObservable(process) {
      log("application is not observable \(process)")
      Workspace.shared.observeActivationPolicy(process)

      guard Workspace.shared.isObservable(process) else { return }
      Workspace.shared.unobserveActivationPolicy(process)
    }

    guard WindowManager.shared.application(by: process.pid) == nil else { return }

    guard let application = Application(for: process) else {
      log("could not create application for process \(process)", level: .warn)
      return
    }

    switch application.observe() {
    case .success:
      break
    case .failure(let error):
      log("could not observe application \(application): \(error)", level: .warn)
      application.unobserve()

      if application.retryObserving {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          guard let process = ProcessManager.shared.find(by: process.psn) else { return }
          EventManager.shared.post(.application(.launched(process)))
        }
      }

      return
    }

    WindowManager.shared.add(application: application)
    WindowManager.shared.addWindows(for: application)

    log("application launched \(application)", level: .info)

    for listener in Event.callbacks(for: .applicationLaunched) {
      listener.call(withArguments: [application])
    }
  }

  private func applicationTerminated(for process: Process) {
    Workspace.shared.unobserveActivationPolicy(process)
    Workspace.shared.unobserveFinishedLaunching(process)

    guard let application = WindowManager.shared.application(by: process.pid) else { return }

    for listener in Event.callbacks(for: .applicationTerminated) {
      listener.call(withArguments: [application])
    }

    WindowManager.shared.remove(application: application)

    let windows = WindowManager.shared.allWindows(for: application)

    for window in windows {
      WindowManager.shared.remove(by: window.id)
      window.invalidate()
    }

    application.unobserve()

    log("application terminated \(application)", level: .info)
  }

  private func applicationFrontSwitched(for process: Process) {
    guard let application = WindowManager.shared.application(by: process.pid) else { return }

    WindowManager.shared.refreshWindows(for: application)

    log("frontmost application switched \(application)", level: .info)

    for listener in Event.callbacks(for: .applicationFrontSwitched) {
      listener.call(withArguments: [application])
    }
  }
}

private struct WindowLifecycleHandler {
  func handle(_ event: WindowEvent) {
    switch event {
    case .created(let element):
      windowCreated(with: element)
    case .destroyed(let window):
      windowDestroyed(with: window)
    case .focused(let windowID):
      windowFocused(with: windowID)
    case .moved(let windowID):
      windowMoved(with: windowID)
    case .resized(let windowID):
      windowResized(with: windowID)
    case .minimized(let window):
      windowMinimized(with: window)
    case .deminimized(let window):
      windowDeminimized(with: window)
    }
  }

  private func windowCreated(with element: AXUIElement) {
    let windowID = Window.id(for: element)

    guard WindowManager.shared.window(by: windowID) == nil else { return }
    guard let pid = Window.pid(for: element) else { return }
    guard let application = WindowManager.shared.application(by: pid) else { return }
    guard let window = WindowManager.shared.addWindow(for: application, with: element) else {
      return
    }

    log("window created \(window)", level: .info)

    for listener in Event.callbacks(for: .windowCreated) {
      listener.call(withArguments: [window])
    }
  }

  private func windowDestroyed(with window: Window) {
    guard window.id != 0 else { return }

    for listener in Event.callbacks(for: .windowDestroyed) {
      listener.call(withArguments: [window])
    }

    log("window destroyed \(window)", level: .info)

    WindowManager.shared.remove(by: window.id)
    window.invalidate()
  }

  private func windowFocused(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = WindowManager.shared.window(by: windowID) else { return }

    log("window focused \(window)", level: .info)

    for listener in Event.callbacks(for: .windowFocused) {
      listener.call(withArguments: [window])
    }
  }

  private func windowMoved(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = WindowManager.shared.window(by: windowID) else { return }

    log("window moved \(window)", level: .info)

    for listener in Event.callbacks(for: .windowMoved) {
      listener.call(withArguments: [window])
    }
  }

  private func windowResized(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = WindowManager.shared.window(by: windowID) else { return }

    log("window resized \(window)", level: .info)

    for listener in Event.callbacks(for: .windowResized) {
      listener.call(withArguments: [window])
    }
  }

  private func windowMinimized(with window: Window) {
    log("window minimized \(window)", level: .info)

    for listener in Event.callbacks(for: .windowMinimized) {
      listener.call(withArguments: [window])
    }
  }

  private func windowDeminimized(with window: Window) {
    log("window deminimized \(window)", level: .info)

    for listener in Event.callbacks(for: .windowDeminimized) {
      listener.call(withArguments: [window])
    }
  }
}

private struct SpaceLifecycleHandler {
  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    }
  }

  private func spaceChanged(with space: Space) {
    WindowManager.shared.refreshWindows()

    log("space changed \(space)", level: .info)

    for listener in Event.callbacks(for: .spaceChanged) {
      listener.call(withArguments: [space])
    }
  }
}
