import Carbon

class WindowManager {
  static let shared = WindowManager()

  private var applications = [pid_t: Application]()
  private var applicationsToRefresh = [Application]()
  private var windows = [CGWindowID: Window]()

  func start() {
    for process in ProcessManager.shared.all() {
      guard Workspace.shared.isObservable(process) else {
        log("application is not observable \(process)", level: .warn)
        Workspace.shared.observeActivationPolicy(process)
        continue
      }

      let application = Application(for: process)

      guard application.observe() else {
        application.unobserve()
        continue
      }

      add(application: application)
      addExistingWindows(for: application, refreshIndex: -1)
    }
  }

  func add(application: Application) {
    applications[application.processID] = application
  }

  func remove(application: Application) {
    applicationsToRefresh.removeAll { $0 == application }
    applications.removeValue(forKey: application.processID)
  }

  @discardableResult
  func addWindow(for application: Application, with element: AXUIElement) -> Window? {
    let window = Window(with: element, for: application)

    guard window.subrole != nil else { return nil }

    guard window.observe() else {
      window.unobserve()
      return nil
    }

    windows[window.id] = window

    return window
  }

  @discardableResult
  func addWindows(for application: Application) -> [Window] {
    let elements = application.windowElements()
    var result = [Window]()

    for element in elements {
      let windowID = Window.id(for: element)

      guard windowID != 0, windows[windowID] == nil else { continue }

      if let window = addWindow(for: application, with: element) {
        result.append(window)
      }
    }

    return result
  }

  func remove(by windowID: CGWindowID) {
    windows.removeValue(forKey: windowID)
  }

  func application(by pid: pid_t) -> Application? {
    applications[pid]
  }

  func application(by name: String) -> Application? {
    applications.values.first { $0.name == name }
  }

  func allApplications() -> [Application] {
    Array(applications.values)
  }

  func window(by id: CGWindowID) -> Window? {
    windows[id]
  }

  func allWindows(for application: Application) -> [Window] {
    windows.values.filter { $0.application == application }
  }

  func allWindows() -> [Window] {
    Array(windows.values)
  }

  func refreshWindows() {
    for application in applicationsToRefresh {
      refreshWindows(for: application)
    }
  }

  func refreshWindows(for application: Application) {
    guard let idx = applicationsToRefresh.firstIndex(of: application) else { return }

    log("application has windows that are not yet resolved \(application)", level: .info)
    addExistingWindows(for: application, refreshIndex: idx)
  }

  @discardableResult
  private func addExistingWindows(for application: Application, refreshIndex: Int) -> Bool {
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
        addWindow(for: application, with: element)
      }
    }

    if globalWindowList.count != elements.count - emptyCount {
      var unresolvedWindows = globalWindowList.filter { windows[$0] == nil }

      if !unresolvedWindows.isEmpty {
        log("application has windows that are not resolved, attempting workaround \(application)", level: .info)

        resolveWindows(for: application, from: &unresolvedWindows)

        if refreshIndex == -1 && !unresolvedWindows.isEmpty {
          log("workaround failed to resolve all windows \(application)", level: .warn)

          applicationsToRefresh.append(application)
        } else if refreshIndex != -1 && unresolvedWindows.isEmpty {
          log("workaround successfully resolved all windows \(application)", level: .info)

          if applicationsToRefresh.indices.contains(refreshIndex) {
            applicationsToRefresh.remove(at: refreshIndex)
          }

          result = true
        }
      }
    } else if refreshIndex != -1 {
      log("all windows resolved \(application)", level: .info)

      if applicationsToRefresh.indices.contains(refreshIndex) {
        applicationsToRefresh.remove(at: refreshIndex)
      }

      result = true
    }

    return result
  }

  private func resolveWindows(for application: Application, from windowIDs: inout [CGWindowID]) {
    for id in 0...0x7fff {
      guard !windowIDs.isEmpty else { break }

      let token = createRemoteToken(for: application.processID, with: id)

      guard
        let element = _AXUIElementCreateWithRemoteToken(token)?.takeRetainedValue(),
        Window.isWindow(element),
        let windowID = Window.validID(for: element)
      else { continue }

      if let idx = windowIDs.firstIndex(of: windowID) {
        windowIDs.remove(at: idx)
        addWindow(for: application, with: element)
        log("resolved window \(windowID) for \(application)", level: .info)
      }
    }
  }

  private func createRemoteToken(for pid: pid_t, with id: Int) -> CFData {
    var token = Data()

    token.append(contentsOf: withUnsafeBytes(of: pid) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: id) { Data($0) })

    return token as CFData
  }
}
