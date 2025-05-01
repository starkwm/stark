import Carbon

class WindowManager {
  static let shared = WindowManager()

  private(set) var applications = [pid_t: Application]()
  private(set) var applicationsToRefresh = [Application]()
  private(set) var windows = [CGWindowID: Window]()

  func begin() {
    for process in ProcessManager.shared.processes.values {
      guard Workspace.shared.isObservable(process) else {
        debug("application is not observable \(process)")
        Workspace.shared.observeActivationPolicy(process)
        continue
      }

      let application = Application(process: process)

      guard application.observe() else {
        application.unobserve()
        continue
      }

      add(application)
      addWindowsFor(existing: application, refreshIndex: -1)
    }
  }

  func add(_ application: Application) {
    applications[application.processID] = application
  }

  func remove(_ application: Application) {
    applications.removeValue(forKey: application.processID)
  }

  func removeApplicationToRefresh(_ application: Application) {
    if let idx = applicationsToRefresh.firstIndex(of: application) {
      applicationsToRefresh.remove(at: idx)
    }
  }

  @discardableResult
  func add(_ element: AXUIElement, _ application: Application) -> Window? {
    let window = Window(element: element, application: application)

    guard window.subrole != nil else { return nil }

    guard window.observe() else {
      window.unobserve()
      return nil
    }

    windows[window.id] = window

    return window
  }

  func remove(_ windowID: CGWindowID) {
    windows.removeValue(forKey: windowID)
  }

  @discardableResult
  func addWindows(for application: Application) -> [Window] {
    let elements = application.windowElements()
    var result = [Window]()

    for element in elements {
      let windowID = Window.id(for: element)

      guard windowID != 0, windows[windowID] == nil else {
        continue
      }

      if let window = add(element, application) {
        result.append(window)
      }
    }

    return result
  }

  @discardableResult
  func addWindowsFor(existing application: Application, refreshIndex: Int) -> Bool {
    let globalWindowList = application.windowIdentifiers()
    let elements = application.windowElements()

    var result = false
    var emptyCount = 0

    for element in elements {
      let windowID = Window.id(for: element)

      if windowID == 0 {
        emptyCount += 1
        continue
      }

      if !windows.keys.contains(windowID) {
        add(element, application)
      }
    }

    if globalWindowList.count == elements.count - emptyCount {
      debug("all windows resolved \(application)")

      if refreshIndex != -1 {
        if applicationsToRefresh.indices.contains(refreshIndex) {
          applicationsToRefresh.remove(at: refreshIndex)
        }
        result = true
      }
    } else {
      let missing = globalWindowList.contains(where: { windows[$0] == nil })

      if refreshIndex == -1 && missing {
        applicationsToRefresh.append(application)
        debug("not all windows resolved \(application)")
      } else if refreshIndex != -1 && !missing {
        if applicationsToRefresh.indices.contains(refreshIndex) {
          applicationsToRefresh.remove(at: refreshIndex)
          debug("debug: all windows resolved \(application)")
        }
        result = true
      }
    }

    return result
  }

  func windows(for application: Application) -> [Window] {
    return windows.filter { $0.value.application == application }.map { $0.value }
  }
}
