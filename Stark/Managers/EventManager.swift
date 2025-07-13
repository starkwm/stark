import Carbon

class EventManager {
  static let shared = EventManager()

  private let queue: OperationQueue = {
    let q = OperationQueue()
    q.maxConcurrentOperationCount = 1
    return q
  }()

  func post(event: EventType, with object: Any?) {
    queue.addOperation {
      switch event {
      case .applicationLaunched:
        guard let process = object as? Process else { break }
        self.applicationLaunched(for: process)

      case .applicationTerminated:
        guard let process = object as? Process else { break }
        self.applicationTerminated(for: process)

      case .applicationFrontSwitched:
        guard let process = object as? Process else { break }
        self.applicationFrontSwitched(for: process)

      case .windowCreated:
        let element = object as! AXUIElement
        self.windowCreated(with: element)

      case .windowDestroyed:
        guard let window = object as? Window else { break }
        self.windowDestroyed(with: window)

      case .windowFocused:
        guard let windowID = object as? CGWindowID else { break }
        self.windowFocused(with: windowID)

      case .windowMoved:
        guard let windowID = object as? CGWindowID else { break }
        self.windowMoved(with: windowID)

      case .windowResized:
        guard let windowID = object as? CGWindowID else { break }
        self.windowResized(with: windowID)

      case .windowMinimized:
        guard let window = object as? Window else { break }
        self.windowMinimized(with: window)

      case .windowDeminimized:
        guard let window = object as? Window else { break }
        self.windowDeminimized(with: window)

      case .spaceChanged:
        self.spaceChanged()
      }
    }
  }
}

extension EventManager {
  private func applicationLaunched(for process: Process) {
    if process.terminated {
      debug("application terminated during launch \(process)")
      return
    }

    if !Workspace.shared.isFinishedLaunching(process) {
      debug("application has not finishing launching \(process)")
      Workspace.shared.observeFinishedLaunching(process)

      guard Workspace.shared.isFinishedLaunching(process) else { return }
      Workspace.shared.unobserveFinishedLaunching(process)
    }

    if !Workspace.shared.isObservable(process) {
      debug("application is not observable \(process)")
      Workspace.shared.observeActivationPolicy(process)

      guard Workspace.shared.isObservable(process) else { return }
      Workspace.shared.unobserveActivationPolicy(process)
    }

    guard WindowManager.shared.applications[process.pid] == nil else { return }

    let application = Application(for: process)

    if !application.observe() {
      debug("could not observe application \(application)")
      application.unobserve()

      if application.retryObserving {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          guard let process = ProcessManager.shared.find(by: process.psn) else { return }
          EventManager.shared.post(event: .applicationLaunched, with: process)
        }
      }

      return
    }

    WindowManager.shared.add(application: application)
    WindowManager.shared.addWindows(for: application)

    debug("application launched \(application)")
  }

  private func applicationTerminated(for process: Process) {
    Workspace.shared.unobserveActivationPolicy(process)
    Workspace.shared.unobserveFinishedLaunching(process)

    guard let application = WindowManager.shared.applications[process.pid] else { return }

    WindowManager.shared.removeApplicationToRefresh(application: application)
    WindowManager.shared.remove(application: application)

    let windows = WindowManager.shared.windows(for: application)

    for window in windows {
      WindowManager.shared.remove(by: window.id)
      window.unobserve()
      window.element = nil
      window.application = nil
      window.id = 0
    }

    application.unobserve()

    debug("application terminated \(application)")
  }

  private func applicationFrontSwitched(for process: Process) {
    guard let application = WindowManager.shared.applications.first(where: { $0.key == process.pid })?.value else {
      return
    }

    for (idx, app) in WindowManager.shared.applicationsToRefresh.enumerated() {
      if app == application {
        WindowManager.shared.addWindowsFor(existing: app, refreshIndex: idx)
        break
      }
    }

    debug("frontmost application switched \(application)")
  }

  private func windowCreated(with element: AXUIElement) {
    let windowID = Window.id(for: element)

    guard !WindowManager.shared.windows.contains(where: { $0.key == windowID }) else { return }
    guard let pid = Window.pid(for: element) else { return }
    guard let application = WindowManager.shared.applications.first(where: { $0.key == pid })?.value else { return }
    guard let window = WindowManager.shared.addWindow(with: element, for: application) else { return }

    debug("window created \(window)")
  }

  private func windowDestroyed(with window: Window) {
    guard window.id != 0 else { return }

    debug("window destroyed \(window)")

    WindowManager.shared.remove(by: window.id)
    window.element = nil
    window.application = nil
    window.id = 0
  }

  private func windowFocused(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = WindowManager.shared.windows.first(where: { $0.key == windowID })?.value else { return }

    debug("window focused \(window)")
  }

  private func windowMoved(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = WindowManager.shared.windows.first(where: { $0.key == windowID })?.value else { return }

    debug("window moved \(window)")
  }

  private func windowResized(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = WindowManager.shared.windows.first(where: { $0.key == windowID })?.value else { return }

    debug("window resized \(window)")
  }

  private func windowMinimized(with window: Window) {
    debug("window minimized \(window)")
  }

  private func windowDeminimized(with window: Window) {
    debug("window deminimized \(window)")
  }

  private func spaceChanged() {
    for (idx, app) in WindowManager.shared.applicationsToRefresh.enumerated() {
      debug("debug: application has windows that are not yet resolved \(app)")
      WindowManager.shared.addWindowsFor(existing: app, refreshIndex: idx)
    }

    let space = Space.active()

    debug("space changed \(space)")
  }
}
