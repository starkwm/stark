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

      if !Workspace.shared.isFinishedLaunching(process) {
        return
      }

      Workspace.shared.unobserveFinishedLaunching(process)
    }

    if !Workspace.shared.isObservable(process) {
      debug("application is not observable \(process)")
      Workspace.shared.observeActivationPolicy(process)

      if !Workspace.shared.isObservable(process) {
        return
      }

      Workspace.shared.unobserveActivationPolicy(process)
    }

    guard WindowManager.shared.findApplication(by: process.pid) != nil else { return }

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
    WindowManager.shared.add(for: application)

    debug("application launched \(application)")
  }

  private func applicationTerminated(for process: Process) {
    Workspace.shared.unobserveActivationPolicy(process)
    Workspace.shared.unobserveFinishedLaunching(process)

    guard let application = WindowManager.shared.findApplication(by: process.pid) else { return }

    WindowManager.shared.removeApplicationToRefresh(application: application)
    WindowManager.shared.remove(application: application)

    let windows = WindowManager.shared.all(for: application)

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
    guard let application = WindowManager.shared.findApplication(by: process.pid) else { return }

    WindowManager.shared.refresh(for: application)

    debug("frontmost application switched \(application)")
  }

  private func windowCreated(with element: AXUIElement) {
    let windowID = Window.id(for: element)

    guard WindowManager.shared.find(by: windowID) == nil else { return }
    guard let pid = Window.pid(for: element) else { return }
    guard let application = WindowManager.shared.findApplication(by: pid) else { return }
    guard let window = WindowManager.shared.add(with: element, for: application) else { return }

    debug("window created \(window)")
  }

  private func windowDestroyed(with window: Window) {
    if window.id == 0 {
      return
    }

    debug("window destroyed \(window)")

    WindowManager.shared.remove(by: window.id)
    window.element = nil
    window.application = nil
    window.id = 0
  }

  private func windowFocused(with windowID: CGWindowID) {
    if windowID == 0 {
      return
    }

    guard let window = WindowManager.shared.find(by: windowID) else { return }

    debug("window focused \(window)")
  }

  private func windowMoved(with windowID: CGWindowID) {
    if windowID == 0 {
      return
    }

    guard let window = WindowManager.shared.find(by: windowID) else { return }

    debug("window moved \(window)")
  }

  private func windowResized(with windowID: CGWindowID) {
    if windowID == 0 {
      return
    }

    guard let window = WindowManager.shared.find(by: windowID) else { return }

    debug("window resized \(window)")
  }

  private func windowMinimized(with window: Window) {
    debug("window minimized \(window)")
  }

  private func windowDeminimized(with window: Window) {
    debug("window deminimized \(window)")
  }

  private func spaceChanged() {
    WindowManager.shared.refresh()

    let space = Space.active()

    debug("space changed \(space)")
  }
}
