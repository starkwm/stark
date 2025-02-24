import Carbon
import OSLog

class WindowManager {
  static let shared = WindowManager()

  private(set) var applications = [pid_t: Application]()
  private(set) var windows = [CGWindowID: Window]()

  func begin() {
    for process in ProcessManager.shared.processes.values {
      if Workspace.shared.isObservable(process) {
        let application = Application(process: process)

        if application.observe() {
          add(application)
          addWindowsFor(existing: application)
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

  func addWindowsFor(existing application: Application) {
    let elements = application.windowElements()
    let validElements = elements.filter { Window.id(for: $0) != 0 }

    for element in validElements {
      let windowID = Window.id(for: element)

      if !windows.keys.contains(windowID) {
        add(element, application)
      }
    }

    let appWindowIDs = application.windowIdentifiers()
    let unresolvedWindowIDs = appWindowIDs.filter { windows[$0] == nil }

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

      guard let element = createAXElement(from: token),
        isWindow(element: element),
        let windowID = getValidWindowID(for: element)
      else { continue }

      if let idx = unresolvedWindowIDs.firstIndex(of: windowID) {
        unresolvedWindowIDs.remove(at: idx)
        add(element, application)
        debug("resolved window \(windowID) for \(application)")
      }
    }
  }

  func windows(for application: Application) -> [Window] {
    return windows.filter { $0.value.application == application }.map { $0.value }
  }

  private func createAXElement(from token: Data) -> AXUIElement? {
    _AXUIElementCreateWithRemoteToken(token as CFData)?.takeUnretainedValue()
  }

  private func getValidWindowID(for element: AXUIElement) -> CGWindowID? {
    let windowID = Window.id(for: element)
    return windowID != 0 ? windowID : nil
  }

  private func isWindow(element: AXUIElement) -> Bool {
    var role: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role).rawValue == 0
      && role as? String == kAXWindowRole
  }
}
