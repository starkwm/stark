import AppKit
import JavaScriptCore

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

@objc protocol ApplicationJSExport: JSExport {

  static func all() -> [Application]

  static func focused() -> Application?

  static func find(_ name: String) -> Application?

  var name: String? { get }

  var bundleID: String? { get }

  var processID: pid_t { get }

  var isFrontmost: Bool { get }

  var isHidden: Bool { get }

  var isTerminated: Bool { get }

  func windows() -> [Window]

  func activate() -> Bool

  func focus() -> Bool

  func show() -> Bool

  func hide() -> Bool

  func terminate() -> Bool
}

class Application: NSObject, ApplicationJSExport {
  private static let accessibilityClient = AccessibilityClient.live
  private static let processClient = ProcessClient.live
  private static let windowServerClient = WindowServerClient.live
  private static let notificationRegistrar = AXNotificationRegistrar<ApplicationNotifications>(
    notifications: applicationNotifications
  )

  static func all() -> [Application] {
    WindowManager.shared.allApplications()
  }

  static func focused() -> Application? {
    guard let pid = processClient.frontmostProcessID() else { return nil }

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
    var observationError: AXError?

    let observedAllNotifications = Self.notificationRegistrar.observe(
      observedNotifications: &observedNotifications,
      addNotification: { notification in
        Self.accessibilityClient.addNotification(
          observer: observer,
          element: element,
          notification: notification,
          context: context
        )
      },
      onFailure: { notification, result in
        retryObserving = result == .cannotComplete

        log(
          "notification \(notification) not added \(self) (retry: \(retryObserving))",
          level: .warn
        )

        if observationError == nil {
          observationError = .notificationFailed("failed to add notification \(notification)")
        }
      }
    )

    observing = true

    CFRunLoopAddSource(
      CFRunLoopGetMain(),
      AXObserverGetRunLoopSource(observer),
      CFRunLoopMode.defaultMode
    )

    guard observedAllNotifications else {
      return .failure(
        observationError ?? .notificationFailed("not all notifications were added")
      )
    }

    return .success(())
  }

  func unobserve() {
    guard let observer = observer else { return }
    Self.notificationRegistrar.unobserve(
      observedNotifications: &observedNotifications,
      removeNotification: { notification in
        Self.accessibilityClient.removeNotification(
          observer: observer,
          element: element,
          notification: notification
        )
      }
    )

    if observing {
      CFRunLoopSourceInvalidate(AXObserverGetRunLoopSource(observer))
      observing = false
    }

    self.observer = nil
  }

  func windowIdentifiers() -> [CGWindowID] {
    Self.windowServerClient.windowIdentifiers(
      connectionID: Space.connection,
      applicationConnectionID: connection,
      spaceIDs: Space.all().map(\.id)
    )
  }

  func windowElements() -> [AXUIElement] {
    Self.accessibilityClient.windowElements(for: element)
  }

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
    EventManager.shared.post(windowCreatedWithElement: element)

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
