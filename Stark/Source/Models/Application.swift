import JavaScriptCore

/// The accessibility attribute for enhanced user interface.
///
/// - Note: This is undocumented.
private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

/// The protocol for the exported attributes of Application.
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

  func windows(_ options: [String: AnyObject]) -> [Window]

  func activate() -> Bool
  func focus() -> Bool

  func show() -> Bool
  func hide() -> Bool

  func terminate() -> Bool
}

extension Application: ApplicationJSExport {}

/// Application represents an application that is currently running.
public class Application: NSObject {
  /// Get an array of Application for all the running applications.
  public static func all() -> [Application] {
    NSWorkspace.shared.runningApplications.map { Application(pid: $0.processIdentifier) }
  }

  /// Get an Application for the frontmost running application.
  public static func focused() -> Application? {
    return NSWorkspace.shared.frontmostApplication.map { app in
      Application(pid: app.processIdentifier)
    }
  }

  /// Get an Application from the running application with the given name.
  public static func find(_ name: String) -> Application? {
    return NSWorkspace.shared.runningApplications.first { $0.localizedName == name }.map { app in
      Application(pid: app.processIdentifier)
    }
  }

  /// The localised name of the application, or a blank string.
  public var name: String { app.localizedName ?? "" }

  /// The bundle identifier for the application, or a blank string.
  public var bundleID: String { app.bundleIdentifier ?? "" }

  /// The process identifier for the application.
  public var processID: pid_t { app.processIdentifier }

  /// Indicates if the application is the current frontmost application.
  public var isActive: Bool { app.isActive }

  /// Indicates if the application is currently hidden.
  public var isHidden: Bool {
    var value: AnyObject?

    guard AXUIElementCopyAttributeValue(element, kAXHiddenAttribute as CFString, &value) == .success,
      let number = value as? NSNumber
    else {
      return false
    }

    return number.boolValue
  }

  /// Indicates if the application is terminated.
  public var isTerminated: Bool {
    app.isTerminated
  }

  /// Initialise using the given process identifier.
  init(pid: pid_t) {
    element = AXUIElementCreateApplication(pid)
    app = NSRunningApplication(processIdentifier: pid)!
  }

  /// The running application instance for the application.
  private var app: NSRunningApplication

  /// The accessibility object for the application.
  private var element: AXUIElement

  /// Initialise using the given running application.
  init(app: NSRunningApplication) {
    element = AXUIElementCreateApplication(app.processIdentifier)
    self.app = app
  }

  /// Get an array of Window for the application.
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

  /// Activate the application and bring all windows forward.
  public func activate() -> Bool {
    app.activate(options: .activateAllWindows)
  }

  /// Activate the application.
  public func focus() -> Bool {
    app.activate(options: [])
  }

  /// Show the application if it is hidden.
  public func show() -> Bool {
    app.unhide()
  }

  /// Hide the application.
  public func hide() -> Bool {
    app.hide()
  }

  /// Terminate the application.
  public func terminate() -> Bool {
    app.terminate()
  }

  /// Indicates if the application has the accessibility enhanced user interface attribute.
  private func isEnhancedUserInterfaceEnabled() -> Bool {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, kAXEnhancedUserInterface as CFString, &value)

    if result == .success, CFGetTypeID(value) == CFBooleanGetTypeID() {
      return CFBooleanGetValue((value as! CFBoolean))
    }

    return false
  }

  /// Temporarily disable the enhanced user interface accessibility attribute for the app then runs the callback.
  func enhancedUIWorkaround(callback: () -> Void) {
    let enhancedUserInterfaceEnabled = isEnhancedUserInterfaceEnabled()

    if enhancedUserInterfaceEnabled {
      disableEnhancedUserInterface()
    }

    callback()

    if enhancedUserInterfaceEnabled {
      enableEnhancedUserInterface()
    }
  }

  /// Set the accessibility enhanced user interface attribute on the application.
  private func enableEnhancedUserInterface() {
    AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanTrue)
  }

  /// Unset the accessibility enhanced user interface attribute on the application.
  private func disableEnhancedUserInterface() {
    AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanFalse)
  }
}
