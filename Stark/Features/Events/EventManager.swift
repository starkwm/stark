import Carbon

protocol EventWorkspaceManaging {
  func isFinishedLaunching(_ process: Process) -> Bool
  func observeFinishedLaunching(_ process: Process)
  func unobserveFinishedLaunching(_ process: Process)
  func isObservable(_ process: Process) -> Bool
  func observeActivationPolicy(_ process: Process)
  func unobserveActivationPolicy(_ process: Process)
}

protocol EventWindowManaging {
  func add(application: Application)
  func remove(application: Application)
  func application(by pid: pid_t) -> Application?
  func addWindow(for application: Application, with element: AXUIElement) -> Window?
  func addWindows(for application: Application) -> [Window]
  func remove(by windowID: CGWindowID)
  func window(by id: CGWindowID) -> Window?
  func allWindows(for application: Application) -> [Window]
  func refreshWindows()
  func refreshWindows(for application: Application)
}

protocol EventProcessLookup {
  func find(by psn: ProcessSerialNumber) -> Process?
}

final class EventManager {
  static let shared = EventManager()

  private let queue = OperationQueue.main
  private let accessibilityQueue = DispatchQueue(
    label: "dev.tombell.Stark.EventManager.accessibility",
    qos: .userInitiated
  )

  private let workspace: EventWorkspaceManaging
  private let windowManager: EventWindowManaging
  private let processLookup: EventProcessLookup

  private lazy var applicationHandler = ApplicationLifecycleHandler(
    workspace: workspace,
    windowManager: windowManager,
    processLookup: processLookup,
    postEvent: { [weak self] event in
      self?.post(event)
    }
  )
  private lazy var windowHandler = WindowLifecycleHandler(windowManager: windowManager)
  private lazy var spaceHandler = SpaceLifecycleHandler(windowManager: windowManager)

  init(
    workspace: EventWorkspaceManaging = Workspace.shared,
    windowManager: EventWindowManaging = WindowManager.shared,
    processLookup: EventProcessLookup = ProcessManager.shared
  ) {
    self.workspace = workspace
    self.windowManager = windowManager
    self.processLookup = processLookup
  }

  func post(_ event: RuntimeEvent) {
    queue.addOperation { self.handle(event) }
  }

  func post(
    windowIdentifierEvent event: WindowIdentifierEvent,
    withWindowElement element: AXUIElement
  ) {
    let retainedElement = Unmanaged.passRetained(element)

    accessibilityQueue.async {
      let element = retainedElement.takeRetainedValue()
      let windowID = Window.id(for: element)
      self.post(.window(event.runtimeEvent(windowID: windowID)))
    }
  }

  func post(windowCreatedWithElement element: AXUIElement) {
    let retainedElement = Unmanaged.passRetained(element)

    accessibilityQueue.async {
      let element = retainedElement.takeRetainedValue()
      let windowID = Window.id(for: element)

      guard windowID != 0 else { return }
      guard let pid = Window.pid(for: element) else { return }

      self.post(.window(.created(pid, windowID)))
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
  let workspace: EventWorkspaceManaging
  let windowManager: EventWindowManaging
  let processLookup: EventProcessLookup
  let postEvent: (RuntimeEvent) -> Void

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

    if !workspace.isFinishedLaunching(process) {
      log("application has not finished launching \(process)")
      workspace.observeFinishedLaunching(process)

      guard workspace.isFinishedLaunching(process) else { return }
      workspace.unobserveFinishedLaunching(process)
    }

    if !workspace.isObservable(process) {
      log("application is not observable \(process)")
      workspace.observeActivationPolicy(process)

      guard workspace.isObservable(process) else { return }
      workspace.unobserveActivationPolicy(process)
    }

    guard windowManager.application(by: process.pid) == nil else { return }

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
          guard let process = processLookup.find(by: process.psn) else { return }
          postEvent(.application(.launched(process)))
        }
      }

      return
    }

    windowManager.add(application: application)
    _ = windowManager.addWindows(for: application)

    log("application launched \(application)", level: .info)

    for listener in Event.callbacks(for: .applicationLaunched) {
      listener.call(withArguments: [application])
    }
  }

  private func applicationTerminated(for process: Process) {
    workspace.unobserveActivationPolicy(process)
    workspace.unobserveFinishedLaunching(process)

    guard let application = windowManager.application(by: process.pid) else { return }

    for listener in Event.callbacks(for: .applicationTerminated) {
      listener.call(withArguments: [application])
    }

    windowManager.remove(application: application)

    let windows = windowManager.allWindows(for: application)

    for window in windows {
      windowManager.remove(by: window.id)
      window.invalidate()
    }

    application.unobserve()

    log("application terminated \(application)", level: .info)
  }

  private func applicationFrontSwitched(for process: Process) {
    guard let application = windowManager.application(by: process.pid) else { return }

    windowManager.refreshWindows(for: application)

    log("frontmost application switched \(application)", level: .info)

    for listener in Event.callbacks(for: .applicationFrontSwitched) {
      listener.call(withArguments: [application])
    }
  }
}

private struct WindowLifecycleHandler {
  let windowManager: EventWindowManaging

  func handle(_ event: WindowEvent) {
    switch event {
    case .created(let pid, let windowID):
      windowCreated(for: pid, with: windowID)
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

  private func windowCreated(for pid: pid_t, with windowID: CGWindowID) {
    guard windowManager.window(by: windowID) == nil else { return }
    guard let application = windowManager.application(by: pid) else { return }

    let element =
      application.windowElements().first { Window.validID(for: $0) == windowID }

    let window: Window?

    if let element {
      window = windowManager.addWindow(for: application, with: element)
    } else {
      _ = windowManager.addWindows(for: application)
      window = windowManager.window(by: windowID)
    }

    guard let window else { return }

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

    windowManager.remove(by: window.id)
    window.invalidate()
  }

  private func windowFocused(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = windowManager.window(by: windowID) else { return }

    log("window focused \(window)", level: .info)

    for listener in Event.callbacks(for: .windowFocused) {
      listener.call(withArguments: [window])
    }
  }

  private func windowMoved(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = windowManager.window(by: windowID) else { return }

    log("window moved \(window)", level: .info)

    for listener in Event.callbacks(for: .windowMoved) {
      listener.call(withArguments: [window])
    }
  }

  private func windowResized(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = windowManager.window(by: windowID) else { return }

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
  let windowManager: EventWindowManaging

  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    }
  }

  private func spaceChanged(with space: Space) {
    windowManager.refreshWindows()

    log("space changed \(space)", level: .info)

    for listener in Event.callbacks(for: .spaceChanged) {
      listener.call(withArguments: [space])
    }
  }
}

extension Workspace: EventWorkspaceManaging {}
extension WindowManager: EventWindowManaging {}
extension ProcessManager: EventProcessLookup {}
