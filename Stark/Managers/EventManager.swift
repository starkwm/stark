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

    let application = Application(for: process)

    if !application.observe() {
      log("could not observe application \(application)", level: .warn)
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

    log("application launched \(application)", level: .info)
  }

  private func applicationTerminated(for process: Process) {
    Workspace.shared.unobserveActivationPolicy(process)
    Workspace.shared.unobserveFinishedLaunching(process)

    guard let application = WindowManager.shared.application(by: process.pid) else { return }

    WindowManager.shared.remove(application: application)

    let windows = WindowManager.shared.allWindows(for: application)

    for window in windows {
      WindowManager.shared.remove(by: window.id)
      window.unobserve()
      window.element = nil
      window.application = nil
      window.id = 0
    }

    application.unobserve()

    log("application terminated \(application)", level: .info)
  }

  private func applicationFrontSwitched(for process: Process) {
    guard let application = WindowManager.shared.application(by: process.pid) else { return }

    WindowManager.shared.refreshWindows(for: application)

    log("frontmost application switched \(application)", level: .info)
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
  }

  private func windowDestroyed(with window: Window) {
    guard window.id != 0 else { return }

    log("window destroyed \(window)", level: .info)

    WindowManager.shared.remove(by: window.id)
    window.unobserve()
    window.element = nil
    window.application = nil
    window.id = 0
  }

  private func windowFocused(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = WindowManager.shared.window(by: windowID) else { return }

    log("window focused \(window)", level: .info)
  }

  private func windowMoved(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = WindowManager.shared.window(by: windowID) else { return }

    log("window moved \(window)", level: .info)
  }

  private func windowResized(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = WindowManager.shared.window(by: windowID) else { return }

    log("window resized \(window)", level: .info)
  }

  private func windowMinimized(with window: Window) {
    log("window minimized \(window)", level: .info)
  }

  private func windowDeminimized(with window: Window) {
    log("window deminimized \(window)", level: .info)
  }

  private func spaceChanged() {
    WindowManager.shared.refreshWindows()

    let space = Space.active()

    log("space changed \(space)", level: .info)
  }
}
