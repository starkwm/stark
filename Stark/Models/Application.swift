import AppKit
import JavaScriptCore

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

/// Protocol exposing application management functionality to JavaScript.
/// Provides access to running applications and their windows.
@objc protocol ApplicationJSExport: JSExport {
  // MARK: - Application Retrieval

  /// Returns all running applications.
  /// - Returns: Array of all applications
  static func all() -> [Application]

  /// Returns the frontmost (active) application.
  /// - Returns: The frontmost application, or nil if none
  static func focused() -> Application?

  /// Finds an application by name.
  /// - Parameter name: The application name to search for
  /// - Returns: The matching application, or nil if not found
  static func find(_ name: String) -> Application?

  // MARK: - Properties

  /// The application's display name.
  var name: String? { get }

  /// The application's bundle identifier (e.g., "com.apple.Safari").
  var bundleID: String? { get }

  /// The application's process identifier.
  var processID: pid_t { get }

  /// Whether this application is currently frontmost.
  var isFrontmost: Bool { get }

  /// Whether this application is hidden.
  var isHidden: Bool { get }

  /// Whether this application has terminated.
  var isTerminated: Bool { get }

  // MARK: - Application Control

  /// Returns all windows belonging to this application.
  /// - Returns: Array of windows
  func windows() -> [Window]

  /// Activates the application, bringing it to the front with all windows.
  /// - Returns: true if successful
  func activate() -> Bool

  /// Focuses the application without activating all windows.
  /// - Returns: true if successful
  func focus() -> Bool

  /// Unhides the application.
  /// - Returns: true if successful
  func show() -> Bool

  /// Hides the application.
  /// - Returns: true if successful
  func hide() -> Bool

  /// Terminates the application.
  /// - Returns: true if successful
  func terminate() -> Bool
}

class Application: NSObject, ApplicationJSExport {
  static func all() -> [Application] {
    WindowManager.shared.allApplications()
  }

  static func focused() -> Application? {
    var psn = ProcessSerialNumber()
    guard _SLPSGetFrontProcess(&psn) == noErr else { return nil }

    var pid = pid_t()
    guard GetProcessPID(&psn, &pid) == noErr else { return nil }

    guard let application = WindowManager.shared.application(by: pid) else { return nil }

    return WindowManager.shared.application(by: application.processID)
  }

  static func find(_ name: String) -> Application? {
    WindowManager.shared.application(by: name)
  }

  override var description: String {
    "<Application pid: \(processID), name: \(name ?? "-"), bundle: \(bundleID ?? "-")>"
  }

  var name: String? {
    application.localizedName
  }

  var bundleID: String? {
    application.bundleIdentifier
  }

  var processID: pid_t {
    application.processIdentifier
  }

  var isFrontmost: Bool {
    application.isActive
  }

  var isHidden: Bool {
    var value: AnyObject?

    guard
      AXUIElementCopyAttributeValue(element, kAXHiddenAttribute as CFString, &value) == .success,
      let number = value as? NSNumber
    else {
      return false
    }

    return number.boolValue
  }

  var isTerminated: Bool {
    application.isTerminated
  }

  private(set) var observer: AXObserver?
  private(set) var retryObserving = false

  private(set) var element: AXUIElement

  private var application: NSRunningApplication

  private var connection: Int32 = -1

  private var observedNotifications = ApplicationNotifications(rawValue: 0)
  private var observing = false

  init?(for process: Process) {
    element = AXUIElementCreateApplication(process.pid)

    guard let app = NSRunningApplication(processIdentifier: process.pid) else {
      return nil
    }
    application = app

    SLSGetConnectionIDForPSN(Space.connection, &process.psn, &connection)
  }

  deinit {
    unobserve()
    log("application deinit \(self)")
  }

  func windows() -> [Window] {
    WindowManager.shared.allWindows(for: self)
  }

  func activate() -> Bool {
    application.activate(options: .activateAllWindows)
  }

  func focus() -> Bool {
    application.activate(options: [])
  }

  func show() -> Bool {
    application.unhide()
  }

  func hide() -> Bool {
    application.hide()
  }

  func terminate() -> Bool {
    application.terminate()
  }

  func observe() -> Result<Void, AXError> {
    let result = AXObserverCreate(
      application.processIdentifier,
      accessibilityObserverCallback,
      &observer
    )

    guard result == .success, let observer = observer else {
      return .failure(.observerCreationFailed)
    }

    let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(self).toOpaque()

    for (idx, notification) in applicationNotifications.enumerated() {
      let result = AXObserverAddNotification(observer, element, notification as CFString, context)

      if result == .success || result == .notificationAlreadyRegistered {
        observedNotifications.insert(ApplicationNotifications(rawValue: 1 << idx))
      } else {
        retryObserving = result == .cannotComplete

        log(
          "notification \(notification) not added \(self) (retry: \(retryObserving)",
          level: .warn
        )
        return .failure(.notificationFailed("failed to add notification \(notification)"))
      }
    }

    observing = true

    CFRunLoopAddSource(
      CFRunLoopGetMain(),
      AXObserverGetRunLoopSource(observer),
      CFRunLoopMode.defaultMode
    )

    guard observedNotifications.contains(.all) else {
      return .failure(.notificationFailed("not all notifications were added"))
    }

    return .success(())
  }

  func unobserve() {
    guard
      !observing,
      let observer = observer
    else { return }

    for (idx, notification) in applicationNotifications.enumerated() {
      let notif = ApplicationNotifications(rawValue: 1 << idx)

      guard observedNotifications.contains(notif) else { continue }

      AXObserverRemoveNotification(observer, element, notification as CFString)
      observedNotifications.remove(notif)
    }

    CFRunLoopSourceInvalidate(AXObserverGetRunLoopSource(observer))

    self.observer = nil
    observing = false
  }

  func windowIdentifiers() -> [CGWindowID] {
    let spaces = Space.all().map(\.id) as CFArray

    let options: UInt32 = 0x7
    var setTags: UInt64 = 0
    var clearTags: UInt64 = 0

    let windows = SLSCopyWindowsWithOptionsAndTags(
      Space.connection,
      UInt32(connection),
      spaces,
      options,
      &setTags,
      &clearTags
    )

    let query = SLSWindowQueryWindows(Space.connection, windows, Int32(CFArrayGetCount(windows)))
    let iterator = SLSWindowQueryResultCopyWindows(query)

    var windowIDs = [CGWindowID]()

    while SLSWindowIteratorAdvance(iterator) {
      guard SLSWindowIteratorGetParentID(iterator) == 0 else { continue }

      let level = NSWindow.Level(rawValue: SLSWindowIteratorGetLevel(iterator))
      guard level == .normal || level == .floating || level == .modalPanel else { continue }

      let attributes = SLSWindowIteratorGetAttributes(iterator)
      let tags = SLSWindowIteratorGetTags(iterator)
      guard validWindow(attributes, tags) else { continue }

      let id = SLSWindowIteratorGetWindowID(iterator)
      windowIDs.append(id)
    }

    return windowIDs
  }

  func windowElements() -> [AXUIElement] {
    var values: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &values) != .success
    {
      return []
    }

    guard let windows = values as? [AXUIElement] else { return [] }

    return windows
  }

  /// Workaround for applications with Enhanced User Interface enabled (e.g., Slack, Discord).
  /// Some applications block programmatic window manipulation when this feature is enabled.
  /// This method temporarily disables it, executes the callback, then restores the original state.
  /// - Parameter callback: The window manipulation code to execute
  func enhancedUIWorkaround(callback: () -> Void) {
    let enhancedUserInterfaceEnabled = isEnhancedUIEnabled()

    if enhancedUserInterfaceEnabled {
      AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanFalse)
    }

    callback()

    if enhancedUserInterfaceEnabled {
      AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanTrue)
    }
  }

  /// Checks if Enhanced User Interface is enabled for this application.
  /// - Returns: true if Enhanced UI is enabled
  private func isEnhancedUIEnabled() -> Bool {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(
      element,
      kAXEnhancedUserInterface as CFString,
      &value
    )

    if result == .success,
      CFGetTypeID(value) == CFBooleanGetTypeID()
    {
      let boolValue = value as! CFBoolean
      return CFBooleanGetValue(boolValue)
    }

    return false
  }

  /// Validates window attributes and tags to determine if it's a real window we should manage.
  /// Uses bitwise operations on window flags from the WindowServer to filter out non-window elements.
  /// - Parameters:
  ///   - attributes: Window attributes from the WindowServer
  ///   - tags: Window tags from the WindowServer
  /// - Returns: true if this represents a valid window we should manage
  private func validWindow(_ attributes: UInt64, _ tags: UInt64) -> Bool {
    // Check for standard window attributes (bit 0x2) or window tags (bit 0x400...)
    // combined with visibility tags (bit 0x1) or active window tags
    if ((attributes & 0x2) != 0 || (tags & 0x400_0000_0000_0000) != 0)
      && (((tags & 0x1) != 0) || ((tags & 0x2) != 0 && (tags & 0x8000_0000) != 0))
    {
      return true
    }

    // Alternative validation for certain window types
    // Checks for minimal attributes with specific tag combinations
    if (attributes == 0x0 || attributes == 0x1)
      && ((tags & 0x1000_0000_0000_0000) != 0 || (tags & 0x300_0000_0000_0000) != 0)
      && (((tags & 0x1) != 0) || ((tags & 0x2) != 0 && (tags & 0x8000_0000) != 0))
    {
      return true
    }

    return false
  }
}

private func accessibilityObserverCallback(
  _ observer: AXObserver,
  _ element: AXUIElement,
  _ notification: CFString,
  _ context: UnsafeMutableRawPointer?
) {
  switch notification as String {
  case kAXCreatedNotification:
    EventManager.shared.post(event: .windowCreated, with: element)

  case kAXFocusedWindowChangedNotification:
    EventManager.shared.post(event: .windowFocused, with: Window.id(for: element))

  case kAXWindowMovedNotification:
    EventManager.shared.post(event: .windowMoved, with: Window.id(for: element))

  case kAXWindowResizedNotification:
    EventManager.shared.post(event: .windowResized, with: Window.id(for: element))

  case kAXWindowMiniaturizedNotification:
    guard let context else { return }
    let windowID = CGWindowID(UInt(bitPattern: context))
    guard let window = WindowManager.shared.window(by: windowID) else { return }
    EventManager.shared.post(event: .windowMinimized, with: window)

  case kAXWindowDeminiaturizedNotification:
    guard let context = context else { return }
    let windowID = CGWindowID(UInt(bitPattern: context))
    guard let window = WindowManager.shared.window(by: windowID) else { return }
    EventManager.shared.post(event: .windowDeminimized, with: window)

  case kAXUIElementDestroyedNotification:
    guard let context = context else { return }
    let windowID = CGWindowID(UInt(bitPattern: context))
    guard let window = WindowManager.shared.window(by: windowID) else { return }
    EventManager.shared.post(event: .windowDestroyed, with: window)

  default:
    break
  }
}
