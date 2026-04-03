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
  private static let accessibilityClient = AccessibilityClient.live
  private static let processClient = ProcessClient.live
  private static let windowServerClient = WindowServerClient.live

  /// Returns all applications currently tracked by the window manager.
  static func all() -> [Application] {
    WindowManager.shared.allApplications()
  }

  /// Returns the frontmost tracked application, if one can be resolved.
  static func focused() -> Application? {
    guard let pid = processClient.frontmostProcessID() else { return nil }

    guard let application = WindowManager.shared.application(by: pid) else { return nil }

    return WindowManager.shared.application(by: application.processID)
  }

  /// Looks up a tracked application by its localized name.
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
    Self.accessibilityClient.boolAttribute(for: element, attribute: kAXHiddenAttribute as String)
      ?? false
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

  /// Wraps a running process with its AX application element and SkyLight connection id.
  init?(for process: Process) {
    element = Self.accessibilityClient.applicationElement(for: process.pid)

    guard let app = NSRunningApplication(processIdentifier: process.pid) else {
      return nil
    }
    application = app

    if let connectionID = Self.processClient.connectionID(
      for: process.psn,
      mainConnectionID: Space.connection
    ) {
      connection = connectionID
    }
  }

  deinit {
    unobserve()
    log("application deinit \(self)")
  }

  /// Returns the tracked windows currently associated with this application.
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

  /// Installs the AX observer and subscribes to app-level window notifications.
  func observe() -> Result<Void, AXError> {
    switch Self.accessibilityClient.createObserver(
      processID: application.processIdentifier,
      callback: accessibilityObserverCallback
    ) {
    case .success(let observer):
      self.observer = observer
    case .failure(let error):
      return .failure(error)
    }

    guard let observer else { return .failure(.observerCreationFailed) }

    let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(self).toOpaque()

    for (idx, notification) in applicationNotifications.enumerated() {
      let result = Self.accessibilityClient.addNotification(
        observer: observer,
        element: element,
        notification: notification,
        context: context
      )

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

  /// Removes any AX notifications and invalidates the app-level observer.
  func unobserve() {
    guard let observer = observer else { return }

    for (idx, notification) in applicationNotifications.enumerated() {
      let notif = ApplicationNotifications(rawValue: 1 << idx)

      guard observedNotifications.contains(notif) else { continue }

      Self.accessibilityClient.removeNotification(
        observer: observer,
        element: element,
        notification: notification
      )
      observedNotifications.remove(notif)
    }

    if observing {
      CFRunLoopSourceInvalidate(AXObserverGetRunLoopSource(observer))
      observing = false
    }

    self.observer = nil
  }

  /// Returns the window server ids currently owned by this application across all spaces.
  func windowIdentifiers() -> [CGWindowID] {
    Self.windowServerClient.windowIdentifiers(
      connectionID: Space.connection,
      applicationConnectionID: connection,
      spaceIDs: Space.all().map(\.id)
    )
  }

  /// Returns the application's current AX window elements.
  func windowElements() -> [AXUIElement] {
    Self.accessibilityClient.windowElements(for: element)
  }

  /// Workaround for applications with Enhanced User Interface enabled (e.g., Slack, Discord).
  /// Some applications block programmatic window manipulation when this feature is enabled.
  /// This method temporarily disables it, executes the callback, then restores the original state.
  /// - Parameter callback: The window manipulation code to execute
  func enhancedUIWorkaround(callback: () -> Void) {
    let enhancedUserInterfaceEnabled = isEnhancedUIEnabled()

    if enhancedUserInterfaceEnabled {
      Self.accessibilityClient.setAttributeValue(
        kCFBooleanFalse,
        for: element,
        attribute: kAXEnhancedUserInterface
      )
    }

    callback()

    if enhancedUserInterfaceEnabled {
      Self.accessibilityClient.setAttributeValue(
        kCFBooleanTrue,
        for: element,
        attribute: kAXEnhancedUserInterface
      )
    }
  }

  /// Checks if Enhanced User Interface is enabled for this application.
  /// - Returns: true if Enhanced UI is enabled
  private func isEnhancedUIEnabled() -> Bool {
    Self.accessibilityClient.enhancedUIEnabled(
      for: element,
      attribute: kAXEnhancedUserInterface
    )
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
    EventManager.shared.post(.window(.created(element)))

  case kAXFocusedWindowChangedNotification:
    EventManager.shared.post(windowIdentifierEvent: .focused, withWindowElement: element)

  case kAXWindowMovedNotification:
    EventManager.shared.post(windowIdentifierEvent: .moved, withWindowElement: element)

  case kAXWindowResizedNotification:
    EventManager.shared.post(windowIdentifierEvent: .resized, withWindowElement: element)

  case kAXWindowMiniaturizedNotification:
    guard let context else { return }
    let windowID = CGWindowID(UInt(bitPattern: context))
    guard let window = WindowManager.shared.window(by: windowID) else { return }
    EventManager.shared.post(.window(.minimized(window)))

  case kAXWindowDeminiaturizedNotification:
    guard let context = context else { return }
    let windowID = CGWindowID(UInt(bitPattern: context))
    guard let window = WindowManager.shared.window(by: windowID) else { return }
    EventManager.shared.post(.window(.deminimized(window)))

  case kAXUIElementDestroyedNotification:
    guard let context = context else { return }
    let windowID = CGWindowID(UInt(bitPattern: context))
    guard let window = WindowManager.shared.window(by: windowID) else { return }
    EventManager.shared.post(.window(.destroyed(window)))

  default:
    break
  }
}
