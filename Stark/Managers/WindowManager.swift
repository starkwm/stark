import Carbon

class WindowManager {
  static let shared = WindowManager()

  private(set) var applications = [pid_t: Application]()
  private(set) var applicationsToRefresh = [Application]()
  private(set) var windows = [CGWindowID: Window]()

  func begin() {
    for process in ProcessManager.shared.all() {
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

    if globalWindowList.count != elements.count - emptyCount {
      var unresolvedWindows = globalWindowList.filter { windows[$0] == nil }

      if !unresolvedWindows.isEmpty {
        debug("application has windows that are not resolved, attempting workaround \(application)")

        resolveWindows(for: application, unresolved: &unresolvedWindows)

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

  func resolveWindows(for application: Application, unresolved windowIDs: inout [CGWindowID]) {
    for id in 0...0x7fff {
      guard !windowIDs.isEmpty else { break }

      let token = createRemoteToken(for: application.processID, id: id)

      guard let element = _AXUIElementCreateWithRemoteToken(token)?.takeUnretainedValue(),
        Window.isWindow(element),
        let windowID = Window.validID(for: element)
      else { continue }

      if let idx = windowIDs.firstIndex(of: windowID) {
        windowIDs.remove(at: idx)
        add(element, application)
        debug("resolved window \(windowID) for \(application)")
      }
    }
  }

  func windows(for application: Application) -> [Window] {
    return windows.values.filter { $0.application == application }
  }

  private func createRemoteToken(for processID: pid_t, id: Int) -> CFData {
    var token = Data()

    token.append(contentsOf: withUnsafeBytes(of: processID) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: id) { Data($0) })

    return token as CFData
  }
}
