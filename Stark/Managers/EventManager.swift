import Carbon
import OSLog

class EventManager {
  static let shared = EventManager()

  private let queue = OperationQueue()

  func begin() -> Bool {
    queue.maxConcurrentOperationCount = 1
    return true
  }

  func post(event: EventType, object: Any?) {
    queue.addOperation {
      switch event {
      case .applicationLaunched:
        guard let process = object as? Process else { break }
        self.applicationLaunched(process)

      case .applicationTerminated:
        guard let process = object as? Process else { break }
        self.applicationTerminated(process)

      case .applicationFrontSwitched:
        guard let process = object as? Process else { break }
        self.applicationFrontSwitched(process)

      case .windowCreated:
        let element = object as! AXUIElement
        self.windowCreated(element)

      case .windowDestroyed:
        guard let window = object as? Window else { break }
        self.windowDestroyed(window)

      case .windowFocused:
        guard let windowID = object as? CGWindowID else { break }
        self.windowFocused(windowID)

      case .windowMoved:
        guard let windowID = object as? CGWindowID else { break }
        self.windowMoved(windowID)

      case .windowResized:
        guard let windowID = object as? CGWindowID else { break }
        self.windowResized(windowID)

      case .windowMinimized:
        guard let window = object as? Window else { break }
        self.windowMinimized(window)

      case .windowDeminimized:
        guard let window = object as? Window else { break }
        self.windowDeminimized(window)

      case .spaceChanged:
        self.spaceChanged()
      }
    }
  }
}

extension EventManager {
  private func applicationLaunched(_ process: Process) {
    if process.terminated {
      debug("application terminated during launch \(process)")
      return
    }

    if !Workspace.shared.isFinishedLaunching(process) {
      debug("application has not finishing launching \(process)")
      Workspace.shared.observeFinishedLaunching(process)

      if Workspace.shared.isFinishedLaunching(process) {
        Workspace.shared.unobserveFinishedLaunching(process)
      } else {
        return
      }
    }

    if !Workspace.shared.isObservable(process) {
      debug("application is not observable \(process)")
      Workspace.shared.observeActivationPolicy(process)

      if Workspace.shared.isObservable(process) {
        Workspace.shared.unobserveActivationPolicy(process)
      } else {
        return
      }
    }

    if WindowManager.shared.applications[process.pid] != nil {
      return
    }

    let application = Application(process: process)

    if !application.observe() {
      debug("could not observe application \(application)")
      application.unobserve()

      if application.retryObserving {
        guard let proc = ProcessManager.shared.processes[process.psn.lowLongOfPSN] else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          EventManager.shared.post(event: .applicationLaunched, object: proc)
        }
      }

      return
    }

    WindowManager.shared.add(application)
    WindowManager.shared.addWindows(for: application)

    debug("application launched \(application)")
  }

  private func applicationTerminated(_ process: Process) {
    Workspace.shared.unobserveActivationPolicy(process)
    Workspace.shared.unobserveFinishedLaunching(process)

    guard let application = WindowManager.shared.applications[process.pid] else { return }

    WindowManager.shared.removeApplicationToRefresh(application)
    WindowManager.shared.remove(application)

    let windows = WindowManager.shared.windows(for: application)

    for window in windows {
      WindowManager.shared.remove(window.id)
      window.unobserve()
      window.element = nil
      window.application = nil
      window.id = 0
    }

    application.unobserve()

    debug("application terminated \(application)")
  }

  private func applicationFrontSwitched(_ process: Process) {
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

  private func windowCreated(_ element: AXUIElement) {
    let windowID = Window.id(for: element)

    if WindowManager.shared.windows.contains(where: { $0.key == windowID }) {
      return
    }

    guard let pid = Window.pid(for: element) else { return }
    guard let application = WindowManager.shared.applications.first(where: { $0.key == pid })?.value else { return }
    guard let window = WindowManager.shared.add(element, application) else { return }

    debug("window created \(window)")
  }

  private func windowDestroyed(_ window: Window) {
    if window.id == 0 {
      return
    }

    debug("window destroyed \(window)")

    WindowManager.shared.remove(window.id)
    window.element = nil
    window.application = nil
    window.id = 0
  }

  private func windowFocused(_ windowID: CGWindowID) {
    if windowID == 0 {
      return
    }

    guard let window = WindowManager.shared.windows.first(where: { $0.key == windowID })?.value else { return }

    debug("debug: window focused \(window)")
  }

  private func windowMoved(_ windowID: CGWindowID) {
    if windowID == 0 {
      return
    }

    guard let window = WindowManager.shared.windows.first(where: { $0.key == windowID })?.value else { return }

    debug("debug: window moved \(window)")
  }

  private func windowResized(_ windowID: CGWindowID) {
    if windowID == 0 {
      return
    }

    guard let window = WindowManager.shared.windows.first(where: { $0.key == windowID })?.value else { return }

    debug("debug: window resized \(window)")
  }

  private func windowMinimized(_ window: Window) {
    debug("debug: window minimized \(window)")
  }

  private func windowDeminimized(_ window: Window) {
    debug("debug: window deminimized \(window)")
  }

  private func spaceChanged() {
    for (idx, app) in WindowManager.shared.applicationsToRefresh.enumerated() {
      debug("debug: application has windows that are not yet resolved \(app)")
      WindowManager.shared.addWindowsFor(existing: app, refreshIndex: idx)
    }

    let space = Space.active()

    debug("debug: space changed \(space)")
  }
}
