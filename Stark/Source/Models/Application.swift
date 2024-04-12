import JavaScriptCore

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

@objc protocol ApplicationJSExport: JSExport {
  static func find(_ name: String) -> Application?
  static func all() -> [Application]
  static func focused() -> Application?

  var name: String { get }
  var bundleID: String { get }
  var processID: pid_t { get }

  var isActive: Bool { get }
  var isHidden: Bool { get }
  var isTerminated: Bool { get }

  func windows() -> [Window]

  func activate() -> Bool
  func focus() -> Bool

  func show() -> Bool
  func hide() -> Bool

  func terminate() -> Bool
}

extension Application: ApplicationJSExport {}

extension Application {
  override var description: String {
    "<Application pid: \(processID), name: \(name), bundle: \(bundleID)>"
  }
}

class Application: NSObject {
  static func all() -> [Application] {
    NSWorkspace.shared.runningApplications.map { Application(pid: $0.processIdentifier) }
  }

  static func focused() -> Application? {
    return NSWorkspace.shared.frontmostApplication.map { app in
      Application(pid: app.processIdentifier)
    }
  }

  static func find(_ name: String) -> Application? {
    return NSWorkspace.shared.runningApplications.first { $0.localizedName == name }.map { app in
      Application(pid: app.processIdentifier)
    }
  }

  var name: String { app.localizedName ?? "nil" }

  var bundleID: String { app.bundleIdentifier ?? "nil" }

  var processID: pid_t { app.processIdentifier }

  var isActive: Bool { app.isActive }

  var isHidden: Bool {
    var value: AnyObject?

    guard AXUIElementCopyAttributeValue(element, kAXHiddenAttribute as CFString, &value) == .success,
      let number = value as? NSNumber
    else {
      return false
    }

    return number.boolValue
  }

  var isTerminated: Bool { app.isTerminated }

  private var app: NSRunningApplication

  private var element: AXUIElement

  init(pid: pid_t) {
    element = AXUIElementCreateApplication(pid)
    app = NSRunningApplication(processIdentifier: pid)!
  }

  init(app: NSRunningApplication) {
    element = AXUIElementCreateApplication(app.processIdentifier)
    self.app = app
  }

  func windows() -> [Window] {
    var values: CFArray?

    if AXUIElementCopyAttributeValues(element, kAXWindowsAttribute as CFString, 0, 100, &values) != .success {
      return []
    }

    guard let windows = values as? [AXUIElement] else {
      return []
    }

    return windows.map { Window(element: $0) }
  }

  func activate() -> Bool {
    app.activate(options: .activateAllWindows)
  }

  func focus() -> Bool {
    app.activate(options: [])
  }

  func show() -> Bool {
    app.unhide()
  }

  func hide() -> Bool {
    app.hide()
  }

  func terminate() -> Bool {
    app.terminate()
  }

  func enhancedUIWorkaround(callback: () -> Void) {
    let enhancedUserInterfaceEnabled = isEnhancedUserInterfaceEnabled()

    if enhancedUserInterfaceEnabled {
      AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanFalse)
    }

    callback()

    if enhancedUserInterfaceEnabled {
      AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanTrue)
    }
  }

  private func isEnhancedUserInterfaceEnabled() -> Bool {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, kAXEnhancedUserInterface as CFString, &value)

    if result == .success, CFGetTypeID(value) == CFBooleanGetTypeID() {
      return CFBooleanGetValue((value as! CFBoolean))
    }

    return false
  }
}
