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

  /// Posts an event to be processed asynchronously.
  /// - Parameters:
  ///   - event: The type of event to post
  ///   - object: Optional data associated with the event
  func post(event: EventType, with object: Any?) {
    queue.addOperation { self.handle(event: event, with: object) }
  }

  /// Resolves a window identifier off the main run loop before dispatching the event.
  /// This keeps AX observer callbacks lightweight and avoids blocking the app on
  /// `_AXUIElementGetWindow` when the target process is slow to respond.
  func post(event: EventType, withWindowElement element: AXUIElement) {
    accessibilityQueue.async {
      let windowID = Window.id(for: element)
      self.post(event: event, with: windowID)
    }
  }

  private func handle(event: EventType, with object: Any?) {
    switch event {
    case .applicationLaunched:
      guard let process = object as? Process else { return }
      applicationLaunched(for: process)

    case .applicationTerminated:
      guard let process = object as? Process else { return }
      applicationTerminated(for: process)

    case .applicationFrontSwitched:
      guard let process = object as? Process else { return }
      applicationFrontSwitched(for: process)

    case .windowCreated:
      guard let object else { return }
      windowCreated(with: object as! AXUIElement)

    case .windowDestroyed:
      guard let window = object as? Window else { return }
      windowDestroyed(with: window)

    case .windowFocused:
      guard let windowID = object as? CGWindowID else { return }
      windowFocused(with: windowID)

    case .windowMoved:
      guard let windowID = object as? CGWindowID else { return }
      windowMoved(with: windowID)

    case .windowResized:
      guard let windowID = object as? CGWindowID else { return }
      windowResized(with: windowID)

    case .windowMinimized:
      guard let window = object as? Window else { return }
      windowMinimized(with: window)

    case .windowDeminimized:
      guard let window = object as? Window else { return }
      windowDeminimized(with: window)

    case .spaceChanged:
      guard let space = object as? Space else { return }
      spaceChanged(with: space)
    }
  }
}

extension EventManager {
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
    case .success: break
    case .failure(let error):
      log("could not observe application \(application): \(error)", level: .warn)
      application.unobserve()

      if application.retryObserving {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          guard let process = ProcessManager.shared.find(by: process.psn) else { return }
          Self.shared.post(event: .applicationLaunched, with: process)
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

  private func spaceChanged(with space: Space) {
    WindowManager.shared.refreshWindows()

    log("space changed \(space)", level: .info)

    for listener in Event.callbacks(for: .spaceChanged) {
      listener.call(withArguments: [space])
    }
  }
}
