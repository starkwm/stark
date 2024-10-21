import Carbon
import OSLog

class WindowManager {
  static let shared = WindowManager()

  private(set) var applications = [pid_t: Application]()
  private(set) var applicationsToRefresh = [Application]()
  private(set) var windows = [CGWindowID: Window]()

  func begin() {
    for process in ProcessManager.shared.processes.values {
      if Workspace.shared.isObservable(process) {
        let application = Application(process: process)

        if application.observe() {
          add(application)
          addWindowsFor(existing: application, refreshIndex: -1)
        } else {
          application.unobserve()
        }
      } else {
        debug("application is not observable \(process)")
        Workspace.shared.observeActivationPolicy(process)
      }
    }
  }

  func add(_ application: Application) {
    applications.updateValue(application, forKey: application.processID)
  }

  func remove(_ application: Application) {
    applications.removeValue(forKey: application.processID)
  }

  func removeApplicationToRefresh(_ application: Application) {
    for (idx, app) in applicationsToRefresh.enumerated() {
      if app == application {
        applicationsToRefresh.remove(at: idx)
      }
    }
  }

  @discardableResult
  func add(_ element: AXUIElement, _ application: Application) -> Window? {
    let window = Window(element: element, application: application)

    if window.subrole == nil {
      return nil
    }

    if !window.observe() {
      window.unobserve()
      return nil
    }

    windows.updateValue(window, forKey: window.id)

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

      if windowID == 0 || windows[windowID] != nil {
        continue
      }

      guard let window = add(element, application) else { continue }

      result.append(window)
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
