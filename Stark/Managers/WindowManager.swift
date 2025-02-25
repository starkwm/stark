import Carbon
import OSLog

class WindowManager {
  static let shared = WindowManager()

  private(set) var applications = [pid_t: Application]()
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
      addWindowsFor(existing: application)
    }
  }

  func add(_ application: Application) {
    applications.updateValue(application, forKey: application.processID)
  }

  func remove(_ application: Application) {
    applications.removeValue(forKey: application.processID)
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

  func addWindows(for application: Application) {
    for element in application.windowElements() {
      let windowID = Window.id(for: element)

      guard windowID != 0, windows[windowID] == nil else { return }

      add(element, application)
    }
  }

  func addWindowsFor(existing application: Application) {
    let validElements = application.windowElements().filter { Window.id(for: $0) != 0 }

    for element in validElements {
      let windowID = Window.id(for: element)
      guard !windows.keys.contains(windowID) else { continue }
      add(element, application)
    }

    let unresolvedWindowIDs = application.windowIdentifiers().filter { windows[$0] == nil }

    if !unresolvedWindowIDs.isEmpty {
      resolveWindows(for: application, unresolved: unresolvedWindowIDs)
    }
  }

  func resolveWindows(for application: Application, unresolved windowIDs: [CGWindowID]) {
    debug("unresolved windows for application \(application)")

    var unresolvedWindowIDs = windowIDs

    var baseToken = Data()
    baseToken.append(contentsOf: withUnsafeBytes(of: application.processID) { Data($0) })
    baseToken.append(contentsOf: withUnsafeBytes(of: Int32(0)) { Data($0) })
    baseToken.append(contentsOf: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })

    for id in 0...0xffff {
      if unresolvedWindowIDs.isEmpty {
        break
      }

      var token = baseToken
      token.append(contentsOf: withUnsafeBytes(of: id) { Data($0) })

      guard let element = _AXUIElementCreateWithRemoteToken(token as CFData)?.takeUnretainedValue(),
        Window.isWindow(element),
        let windowID = Window.validID(for: element)
      else { continue }

      if let idx = unresolvedWindowIDs.firstIndex(of: windowID) {
        unresolvedWindowIDs.remove(at: idx)
        add(element, application)
        debug("resolved window \(windowID) for \(application)")
      }
    }
  }

  func windows(for application: Application) -> [Window] {
    return windows.values.filter { $0.application == application }
  }
}
