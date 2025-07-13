import Carbon

class WindowManager {
  static let shared = WindowManager()

  private var applications = [pid_t: Application]()
  private var applicationsToRefresh = [Application]()
  private var windows = [CGWindowID: Window]()

  func begin() {
    for process in ProcessManager.shared.all() {
      guard Workspace.shared.isObservable(process) else {
        debug("application is not observable \(process)")
        Workspace.shared.observeActivationPolicy(process)
        continue
      }

      let application = Application(for: process)

      guard application.observe() else {
        application.unobserve()
        continue
      }

      add(application: application)
      add(for: application, refreshIndex: -1)
    }
  }

  func add(application: Application) {
    applications[application.processID] = application
  }

  func remove(application: Application) {
    applications.removeValue(forKey: application.processID)
  }

  func removeApplicationToRefresh(application: Application) {
    applicationsToRefresh.removeAll { $0 == application }
  }

  @discardableResult
  func add(with element: AXUIElement, for application: Application) -> Window? {
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
  func add(for application: Application) -> [Window] {
    let elements = application.windowElements()
    var result = [Window]()

    for element in elements {
      let windowID = Window.id(for: element)

      guard windowID != 0, windows[windowID] == nil else { continue }

      if let window = add(with: element, for: application) {
        result.append(window)
      }
    }

    return result
  }

  @discardableResult
  func add(for application: Application, refreshIndex: Int) -> Bool {
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
        add(with: element, for: application)
      }
    }

    if globalWindowList.count != elements.count - emptyCount {
      var unresolvedWindows = globalWindowList.filter { windows[$0] == nil }

      if !unresolvedWindows.isEmpty {
        debug("application has windows that are not resolved, attempting workaround \(application)")

        resolve(for: application, from: &unresolvedWindows)

        if refreshIndex == -1 && !unresolvedWindows.isEmpty {
          debug("workaround failed to resolve all windows \(application)")

          applicationsToRefresh.append(application)
        } else if refreshIndex != -1 && unresolvedWindows.isEmpty {
          debug("workaround successfully resolved all windows \(application)")

          if applicationsToRefresh.indices.contains(refreshIndex) {
            applicationsToRefresh.remove(at: refreshIndex)
          }

          result = true
        }
      }
    } else if refreshIndex != -1 {
      debug("all windows resolved \(application)")

      if applicationsToRefresh.indices.contains(refreshIndex) {
        applicationsToRefresh.remove(at: refreshIndex)
      }

      result = true
    }

    return result
  }

  func remove(by id: CGWindowID) {
    windows.removeValue(forKey: id)
  }

  func refresh() {
    for (idx, application) in WindowManager.shared.applicationsToRefresh.enumerated() {
      debug("debug: application has windows that are not yet resolved \(application)")
      add(for: application, refreshIndex: idx)
    }
  }

  func refresh(for application: Application) {
    guard let idx = applicationsToRefresh.firstIndex(of: application) else { return }
    debug("debug: application has windows that are not yet resolved \(application)")
    add(for: application, refreshIndex: idx)
  }

  func resolve(for application: Application, from windowIDs: inout [CGWindowID]) {
    for id in 0...0x7fff {
      guard !windowIDs.isEmpty else { break }

      let token = createRemoteToken(for: application.processID, with: id)

      guard let element = _AXUIElementCreateWithRemoteToken(token)?.takeUnretainedValue(),
        Window.isWindow(element),
        let windowID = Window.validID(for: element)
      else { continue }

      if let idx = windowIDs.firstIndex(of: windowID) {
        windowIDs.remove(at: idx)
        add(with: element, for: application)
        debug("resolved window \(windowID) for \(application)")
      }
    }
  }

  func all() -> [Window] {
    Array(windows.values)
  }

  func find(by id: CGWindowID) -> Window? {
    windows[id]
  }

  func all(for application: Application) -> [Window] {
    windows.values.filter { $0.application == application }
  }

  func allApplications() -> [Application] {
    Array(applications.values)
  }

  func findApplication(by pid: pid_t) -> Application? {
    applications[pid]
  }

  func findApplication(by name: String) -> Application? {
    applications.values.first { $0.name == name }
  }

  private func createRemoteToken(for processID: pid_t, with id: Int) -> CFData {
    var token = Data()

    token.append(contentsOf: withUnsafeBytes(of: processID) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: id) { Data($0) })

    return token as CFData
  }
}
