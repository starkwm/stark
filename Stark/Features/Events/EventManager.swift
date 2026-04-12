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
  private let listenerProvider: EventListenerProviding

  private lazy var dispatcher = RuntimeEventDispatcher(listenerProvider: listenerProvider)
  private lazy var applicationHandler = ApplicationLifecycleHandler(
    workspace: workspace,
    windowManager: windowManager,
    processLookup: processLookup,
    dispatcher: dispatcher,
    postEvent: { [weak self] event in
      self?.post(event)
    }
  )
  private lazy var windowHandler = WindowLifecycleHandler(
    windowManager: windowManager,
    dispatcher: dispatcher
  )
  private lazy var spaceHandler = SpaceLifecycleHandler(
    windowManager: windowManager,
    dispatcher: dispatcher
  )

  init(
    workspace: EventWorkspaceManaging = Workspace.shared,
    windowManager: EventWindowManaging = WindowManager.shared,
    processLookup: EventProcessLookup = ProcessManager.shared,
    listenerProvider: EventListenerProviding = ConfigSessionStore.shared
  ) {
    self.workspace = workspace
    self.windowManager = windowManager
    self.processLookup = processLookup
    self.listenerProvider = listenerProvider
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

private struct RuntimeEventDispatcher {
  let listenerProvider: EventListenerProviding

  func emit(_ type: EventType, payload: Any, message: String, level: LogLevel = .info) {
    log(message, level: level)

    for listener in listenerProvider.callbacks(for: type) {
      listener.call(withArguments: [payload])
    }
  }
}

private struct ApplicationLifecycleHandler {
  let workspace: EventWorkspaceManaging
  let windowManager: EventWindowManaging
  let processLookup: EventProcessLookup
  let dispatcher: RuntimeEventDispatcher
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

    dispatcher.emit(
      .applicationLaunched,
      payload: application,
      message: "application launched \(application)"
    )
  }

  private func applicationTerminated(for process: Process) {
    workspace.unobserveActivationPolicy(process)
    workspace.unobserveFinishedLaunching(process)

    guard let application = windowManager.application(by: process.pid) else { return }

    dispatcher.emit(
      .applicationTerminated,
      payload: application,
      message: "application terminated \(application)"
    )

    windowManager.remove(application: application)

    let windows = windowManager.allWindows(for: application)

    for window in windows {
      windowManager.remove(by: window.id)
      window.invalidate()
    }

    application.unobserve()
  }

  private func applicationFrontSwitched(for process: Process) {
    guard let application = windowManager.application(by: process.pid) else { return }

    windowManager.refreshWindows(for: application)

    dispatcher.emit(
      .applicationFrontSwitched,
      payload: application,
      message: "frontmost application switched \(application)"
    )
  }
}

private struct WindowLifecycleHandler {
  let windowManager: EventWindowManaging
  let dispatcher: RuntimeEventDispatcher

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

    let element = application.windowElements().first { Window.validID(for: $0) == windowID }
    let window: Window?

    if let element {
      window = windowManager.addWindow(for: application, with: element)
    } else {
      _ = windowManager.addWindows(for: application)
      window = windowManager.window(by: windowID)
    }

    guard let window else { return }

    dispatcher.emit(.windowCreated, payload: window, message: "window created \(window)")
  }

  private func windowDestroyed(with window: Window) {
    guard window.id != 0 else { return }

    dispatcher.emit(.windowDestroyed, payload: window, message: "window destroyed \(window)")

    windowManager.remove(by: window.id)
    window.invalidate()
  }

  private func windowFocused(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = windowManager.window(by: windowID) else { return }

    dispatcher.emit(.windowFocused, payload: window, message: "window focused \(window)")
  }

  private func windowMoved(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = windowManager.window(by: windowID) else { return }

    dispatcher.emit(.windowMoved, payload: window, message: "window moved \(window)")
  }

  private func windowResized(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = windowManager.window(by: windowID) else { return }

    dispatcher.emit(.windowResized, payload: window, message: "window resized \(window)")
  }

  private func windowMinimized(with window: Window) {
    dispatcher.emit(.windowMinimized, payload: window, message: "window minimized \(window)")
  }

  private func windowDeminimized(with window: Window) {
    dispatcher.emit(
      .windowDeminimized,
      payload: window,
      message: "window deminimized \(window)"
    )
  }
}

private struct SpaceLifecycleHandler {
  let windowManager: EventWindowManaging
  let dispatcher: RuntimeEventDispatcher

  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    }
  }

  private func spaceChanged(with space: Space) {
    windowManager.refreshWindows()
    dispatcher.emit(.spaceChanged, payload: space, message: "space changed \(space)")
  }
}

extension Workspace: EventWorkspaceManaging {}
extension WindowManager: EventWindowManaging {}
extension ProcessManager: EventProcessLookup {}
