import JavaScriptCore

/// The accessibility attribute for if a window is full screen.
///
/// - Note: This is undocumented.
private let kAXFullScreenAttribute = "AXFullScreen"

/// The options key for visible windows only for functions that get windows.
let starkVisibilityOptionsKey = "visible"

/// The protocol for the exported attributes of WIndow.
@objc protocol WindowJSExport: JSExport {
  static func all(_ options: [String: AnyObject]) -> [Window]
  static func focused() -> Window?

  var id: CGWindowID { get }

  var app: Application { get }
  var screen: NSScreen { get }

  var title: String { get }

  var frame: CGRect { get }
  var topLeft: CGPoint { get }
  var size: CGSize { get }

  var isStandard: Bool { get }
  var isMain: Bool { get }
  var isFullscreen: Bool { get }
  var isMinimized: Bool { get }

  func setFrame(_ frame: CGRect)
  func setTopLeft(_ topLeft: CGPoint)
  func setSize(_ size: CGSize)
  func setFullScreen(_ value: Bool)

  func minimize()
  func unminimize()

  func focus()

  func spaces() -> [Space]
}

extension Window: WindowJSExport {}

/// Window represents a window belonging to a running application.
class Window: NSObject {
  /// A system wide accessibility object for access to system attributes.
  private static let systemWideElement = AXUIElementCreateSystemWide()

  /// Get windows for all running applications.
  static func all(_ options: [String: AnyObject] = [:]) -> [Window] {
    Application.all().flatMap { $0.windows(options) }
  }

  /// Get the currently focused window.
  static func focused() -> Window? {
    var app: AnyObject?

    AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &app)

    if app == nil {
      return nil
    }

    var window: AnyObject?

    if AXUIElementCopyAttributeValue(
      app as! AXUIElement,
      kAXFocusedWindowAttribute as CFString,
      &window
    ) != .success {
      return nil
    }

    return Window(element: window as! AXUIElement)
  }

  /// The identifier for the window.
  var id: CGWindowID {
    var id: CGWindowID = 0
    _AXUIElementGetWindow(element, &id)
    return id
  }

  /// The application the window belongs to.
  var app: Application {
    Application(pid: pid())
  }

  /// The screen that contains the window.
  var screen: NSScreen {
    let windowFrame = frame
    var lastVolume: CGFloat = 0
    var lastScreen = NSScreen()

    for screen in NSScreen.screens {
      let screenFrame = screen.flippedFrame
      let intersection = windowFrame.intersection(screenFrame)
      let volume = intersection.size.width * intersection.size.height

      if volume > lastVolume {
        lastVolume = volume
        lastScreen = screen
      }
    }

    return lastScreen
  }

  /// The title of the window.
  var title: String {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) != .success {
      return ""
    }

    if let title = value as? String {
      return title
    }

    return ""
  }

  /// The frame of the window. This is the coordinates of the top left point, and the width and height of the window.
  var frame: CGRect {
    CGRect(origin: topLeft, size: size)
  }

  /// The coordinates of the top left point of the window.
  var topLeft: CGPoint {
    var value: AnyObject?
    var topLeft = CGPoint.zero

    if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success {
      if !AXValueGetValue(value as! AXValue, AXValueType.cgPoint, &topLeft) {
        topLeft = CGPoint.zero
      }
    }

    return topLeft
  }

  /// The width and height of the window.
  var size: CGSize {
    var value: AnyObject?
    var size = CGSize.zero

    if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success {
      if !AXValueGetValue(value as! AXValue, AXValueType.cgSize, &size) {
        size = CGSize.zero
      }
    }

    return size
  }

  /// Indicates if this window is the main window of the application.
  var isMain: Bool {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXMainAttribute as CFString, &value) != .success {
      return false
    }

    if let number = value as? NSNumber {
      return number.boolValue
    }

    return false
  }

  /// Indicates if this window is a standard window with a titlebar.
  var isStandard: Bool {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value) != .success {
      return false
    }

    if let subrole = value as? String {
      return subrole == kAXStandardWindowSubrole
    }

    return false
  }

  /// Indicates if this window is a full screen window.
  var isFullscreen: Bool {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXFullScreenAttribute as CFString, &value) != .success {
      return false
    }

    if let number = value as? NSNumber {
      return number.boolValue
    }

    return false
  }

  /// Indicates if this window is minimised in the dock.
  var isMinimized: Bool {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value) != .success {
      return false
    }

    if let number = value as? NSNumber {
      return number.boolValue
    }

    return false
  }

  /// The accessibility object for the window.
  private var element: AXUIElement

  /// Initialise with the given accessibility object.
  init(element: AXUIElement) {
    self.element = element
  }

  /// The process identifier of the process the window belongs to.
  private func pid() -> pid_t {
    var pid: pid_t = 0
    let result = AXUIElementGetPid(element, &pid)

    if result != .success {
      return 0
    }

    return pid
  }

  /// Check if the given variable matches this window instance.
  override func isEqual(_ object: Any?) -> Bool {
    guard let window = object as? Self else {
      return false
    }

    return id == window.id
  }

  /// Set the position and size of the window.
  func setFrame(_ frame: CGRect) {
    setTopLeft(frame.origin)
    setSize(frame.size)
  }

  /// Set the top left position of the window.
  func setTopLeft(_ topLeft: CGPoint) {
    app.enhancedUIWorkaround {
      var val = topLeft
      let value = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
      AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }
  }

  /// Set the width and height of the window.
  func setSize(_ size: CGSize) {
    app.enhancedUIWorkaround {
      var val = size
      let value = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
      AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }
  }

  /// Set the window to be full screen.
  func setFullScreen(_ value: Bool) {
    AXUIElementSetAttributeValue(element, kAXFullScreenAttribute as CFString, value as CFTypeRef)
  }

  /// Minimise the window.
  func minimize() {
    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, true as CFTypeRef)
  }

  /// Unminimise the window.
  func unminimize() {
    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, false as CFTypeRef)
  }

  /// Focus the window.
  func focus() {
    if AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue) != .success {
      return
    }

    if let app = NSRunningApplication(processIdentifier: pid()) {
      app.activate()
    }
  }

  /// Get the spaces that contain the window.
  func spaces() -> [Space] {
    Space.spaces(for: self)
  }
}
