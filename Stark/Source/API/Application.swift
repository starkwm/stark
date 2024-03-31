import AppKit

// XXX: Undocumented private attribute for enhanced user interface
private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

private let starkVisibilityOptionsKey = "visible"

public class Application: NSObject, ApplicationJSExport {
  public static func find(_ name: String) -> Application? {
    return NSWorkspace.shared.runningApplications.first { $0.localizedName == name }.map { app in
      Application(pid: app.processIdentifier)
    }
  }

  public static func all() -> [Application] {
    NSWorkspace.shared.runningApplications.map { Application(pid: $0.processIdentifier) }
  }

  public static func focused() -> Application? {
    return NSWorkspace.shared.frontmostApplication.map { app in
      Application(pid: app.processIdentifier)
    }
  }

  private var element: AXUIElement

  private var app: NSRunningApplication

  public var name: String { app.localizedName ?? "" }

  public var bundleId: String { app.bundleIdentifier ?? "" }

  public var processId: pid_t { app.processIdentifier }

  public var isActive: Bool { app.isActive }

  public var isHidden: Bool {
    var value: AnyObject?

    guard AXUIElementCopyAttributeValue(element, kAXHiddenAttribute as CFString, &value) == .success,
      let number = value as? NSNumber
    else {
      return false
    }

    return number.boolValue
  }

  public var isTerminated: Bool {
    app.isTerminated
  }

  init(pid: pid_t) {
    element = AXUIElementCreateApplication(pid)
    app = NSRunningApplication(processIdentifier: pid)!
  }

  init(app: NSRunningApplication) {
    element = AXUIElementCreateApplication(app.processIdentifier)
    self.app = app
  }

  public func windows(_ options: [String: AnyObject] = [:]) -> [Window] {
    var values: CFArray?

    if AXUIElementCopyAttributeValues(element, kAXWindowsAttribute as CFString, 0, 100, &values) != .success {
      return []
    }

    let windows = (values as? [AXUIElement] ?? []).map { Window(element: $0) }

    let visible = options[starkVisibilityOptionsKey] as? Bool ?? false

    if visible {
      return windows.filter { !$0.app.isHidden && $0.isStandard && !$0.isMinimized }
    }

    return windows
  }

  public func activate() -> Bool {
    app.activate(options: .activateAllWindows)
  }

  public func focus() -> Bool {
    app.activate(options: [])
  }

  public func show() -> Bool {
    app.unhide()
  }

  public func hide() -> Bool {
    app.hide()
  }

  public func terminate() -> Bool {
    app.terminate()
  }

  public func isEnhancedUserInterfaceEnabled() -> Bool {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, kAXEnhancedUserInterface as CFString, &value)

    if result == .success, CFGetTypeID(value) == CFBooleanGetTypeID() {
      return CFBooleanGetValue((value as! CFBoolean))
    }

    return false
  }

  public func enableEnhancedUserInterface() {
    AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanTrue)
  }

  public func disableEnhancedUserInterface() {
    AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanFalse)
  }
}
