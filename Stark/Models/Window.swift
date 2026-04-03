import AppKit
import JavaScriptCore

private let systemWideElement = AXUIElementCreateSystemWide()

private let kAXFullScreenAttribute = "AXFullScreen"

/// Protocol exposing window management functionality to JavaScript.
/// All windows in the system can be accessed and manipulated through this interface.
@objc protocol WindowJSExport: JSExport {
  // MARK: - Window Retrieval

  /// Returns all windows currently managed by Stark.
  /// - Returns: Array of all windows
  static func all() -> [Window]

  /// Returns the currently focused window.
  /// - Returns: The focused window, or nil if no window is focused
  static func focused() -> Window?

  // MARK: - Properties

  /// Unique identifier for the window.
  var id: CGWindowID { get }

  /// The application that owns this window.
  var application: Application? { get }

  /// The screen containing this window.
  var screen: NSScreen? { get }

  /// The window's title.
  var title: String { get }

  /// The window's frame rectangle in screen coordinates.
  var frame: CGRect { get }

  /// The window's top-left corner position.
  var topLeft: CGPoint { get }

  /// The window's size.
  var size: CGSize { get }

  /// Whether this is a standard window (not a dialog, menu, etc.).
  var isStandard: Bool { get }

  /// Whether this window is the main window of its application.
  var isMain: Bool { get }

  /// Whether this window is in fullscreen mode.
  var isFullscreen: Bool { get }

  /// Whether this window is minimized.
  var isMinimized: Bool { get }

  // MARK: - Window Manipulation

  /// Sets the window's frame.
  /// - Parameter frame: The new frame rectangle
  func setFrame(_ frame: CGRect)

  /// Sets the window's position.
  /// - Parameter topLeft: The new top-left corner position
  func setTopLeft(_ topLeft: CGPoint)

  /// Sets the window's size.
  /// - Parameter size: The new size
  func setSize(_ size: CGSize)

  /// Sets the window's fullscreen state.
  /// - Parameter value: true to enter fullscreen, false to exit
  func setFullscreen(_ value: Bool)

  /// Minimizes the window.
  func minimize()

  /// Restores the window from minimized state.
  func unminimize()

  /// Focuses the window and activates its application.
  func focus()

  /// Returns all spaces containing this window.
  /// - Returns: Array of spaces
  func spaces() -> [Space]
}

class Window: NSObject, WindowJSExport {
  private static let accessibilityClient = AccessibilityClient.live

  static func all() -> [Window] {
    WindowManager.shared.allWindows()
  }

  static func focused() -> Window? {
    guard let application = Application.focused() else { return nil }

    guard let axElement = accessibilityClient.focusedWindowElement(for: application.element) else {
      return nil
    }

    return WindowManager.shared.window(by: Window.id(for: axElement))
  }

  static func id(for element: AXUIElement) -> CGWindowID {
    accessibilityClient.windowID(for: element)
  }

  static func validID(for element: AXUIElement) -> CGWindowID? {
    let windowID = id(for: element)
    return windowID != 0 ? windowID : nil
  }

  static func isWindow(_ element: AXUIElement) -> Bool {
    accessibilityClient.isWindow(element)
  }

  static func pid(for element: AXUIElement) -> pid_t? {
    accessibilityClient.processID(for: element)
  }

  override var description: String {
    "<Window id: \(id), title: \(title)>"
  }

  var screen: NSScreen? {
    let windowFrame = frame

    return NSScreen.screens.max { a, b in
      let aIntersection = windowFrame.intersection(a.flippedFrame)
      let bIntersection = windowFrame.intersection(b.flippedFrame)

      let aArea = aIntersection.width * aIntersection.height
      let bArea = bIntersection.width * bIntersection.height

      return aArea < bArea
    }
  }

  var title: String {
    guard let element else { return "" }
    return Self.accessibilityClient.stringAttribute(for: element, attribute: kAXTitleAttribute as String)
      ?? ""
  }

  var frame: CGRect {
    CGRect(origin: topLeft, size: size)
  }

  var topLeft: CGPoint {
    guard let element else { return CGPoint.zero }
    return Self.accessibilityClient.pointAttribute(for: element, attribute: kAXPositionAttribute as String)
      ?? CGPoint.zero
  }

  var size: CGSize {
    guard let element else { return CGSize.zero }
    return Self.accessibilityClient.sizeAttribute(for: element, attribute: kAXSizeAttribute as String)
      ?? CGSize.zero
  }

  var isMain: Bool {
    guard let element else { return false }
    return Self.accessibilityClient.isMainWindow(element)
  }

  var subrole: String? {
    guard let element else { return nil }
    return Self.accessibilityClient.subrole(for: element)
  }

  var isStandard: Bool {
    subrole == kAXStandardWindowSubrole
  }

  var isFullscreen: Bool {
    guard let element else { return false }
    return Self.accessibilityClient.boolAttribute(for: element, attribute: kAXFullScreenAttribute) ?? false
  }

  var isMinimized: Bool {
    guard let element else { return false }
    return Self.accessibilityClient.boolAttribute(
      for: element,
      attribute: kAXMinimizedAttribute as String
    ) ?? false
  }

  private(set) var element: AXUIElement?
  weak var application: Application?
  private(set) var id: CGWindowID

  private var observedNotifications = WindowNotifications(rawValue: 0)

  init(with element: AXUIElement, for application: Application) {
    self.element = element
    self.application = application
    id = Window.id(for: element)
  }

  deinit {
    unobserve()
    log("window deinit \(self)")
  }

  func invalidate() {
    unobserve()
    element = nil
    application = nil
    id = 0
  }

  private func pid() -> pid_t? {
    guard let element else { return nil }

    return Window.pid(for: element)
  }

  override func isEqual(_ object: Any?) -> Bool {
    guard let window = object as? Self else { return false }

    return id == window.id
  }

  func setFrame(_ frame: CGRect) {
    setTopLeft(frame.origin)
    setSize(frame.size)
  }

  func setTopLeft(_ topLeft: CGPoint) {
    application?.enhancedUIWorkaround {
      guard let element else { return }
      Self.accessibilityClient.setPoint(topLeft, for: element, attribute: kAXPositionAttribute as String)
    }
  }

  func setSize(_ size: CGSize) {
    application?.enhancedUIWorkaround {
      guard let element else { return }
      Self.accessibilityClient.setSize(size, for: element, attribute: kAXSizeAttribute as String)
    }
  }

  func setFullscreen(_ value: Bool) {
    guard let element else { return }

    Self.accessibilityClient.setAttributeValue(
      value as CFTypeRef,
      for: element,
      attribute: kAXFullScreenAttribute
    )
  }

  func minimize() {
    guard let element else { return }

    Self.accessibilityClient.setAttributeValue(
      true as CFTypeRef,
      for: element,
      attribute: kAXMinimizedAttribute as String
    )
  }

  func unminimize() {
    guard let element else { return }

    Self.accessibilityClient.setAttributeValue(
      false as CFTypeRef,
      for: element,
      attribute: kAXMinimizedAttribute as String
    )
  }

  func focus() {
    guard let element else { return }

    if !Self.accessibilityClient.setAttributeValue(
      kCFBooleanTrue,
      for: element,
      attribute: kAXMainAttribute as String
    ) {
      return
    }

    guard let pid = pid() else { return }

    if let app = NSRunningApplication(processIdentifier: pid) {
      app.activate()
    }
  }

  func spaces() -> [Space] {
    Space.spaces(containing: self)
  }

  func observe() -> Bool {
    guard let observer = application?.observer else { return false }
    guard let element else { return false }

    let context = UnsafeMutableRawPointer(bitPattern: UInt(id))

    for (idx, notification) in windowNotifications.enumerated() {
      let result = Self.accessibilityClient.addNotification(
        observer: observer,
        element: element,
        notification: notification,
        context: context
      )

      if result == .success || result == .notificationAlreadyRegistered {
        observedNotifications.insert(WindowNotifications(rawValue: 1 << idx))
      } else {
        log("notification \(notification) not added \(self)", level: .warn)
      }
    }

    return observedNotifications.contains(.all)
  }

  func unobserve() {
    guard let observer = application?.observer else { return }
    guard let element else { return }

    for (idx, notification) in windowNotifications.enumerated() {
      let notif = WindowNotifications(rawValue: 1 << idx)

      if observedNotifications.contains(notif) {
        Self.accessibilityClient.removeNotification(
          observer: observer,
          element: element,
          notification: notification
        )
        observedNotifications.remove(notif)
      }
    }
  }
}
