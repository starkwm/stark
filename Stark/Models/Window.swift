import AppKit
import JavaScriptCore

private let systemWideElement = AXUIElementCreateSystemWide()

private let kAXFullScreenAttribute = "AXFullScreen"

@objc protocol WindowJSExport: JSExport {
  static func all() -> [Window]
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

extension Window {
  override var description: String {
    "<Window id: \(id), title: \(title)>"
  }
}

class Window: NSObject {
  static func all() -> [Window] {
    Application.all().flatMap { $0.windows() }
  }

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

  var id: CGWindowID {
    var id: CGWindowID = 0
    _AXUIElementGetWindow(element, &id)
    return id
  }

  var app: Application {
    Application(pid: pid())
  }

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

  var frame: CGRect {
    CGRect(origin: topLeft, size: size)
  }

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

  var subrole: String? {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value) != .success {
      return nil
    }

    guard let subrole = value as? String else {
      return nil
    }

    return subrole
  }

  var isStandard: Bool {
    return subrole == kAXStandardWindowSubrole
  }

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

  private var element: AXUIElement

  init(element: AXUIElement) {
    self.element = element
  }

  private func pid() -> pid_t {
    var pid: pid_t = 0
    let result = AXUIElementGetPid(element, &pid)

    if result != .success {
      return 0
    }

    return pid
  }

  override func isEqual(_ object: Any?) -> Bool {
    guard let window = object as? Self else {
      return false
    }

    return id == window.id
  }

  func setFrame(_ frame: CGRect) {
    setTopLeft(frame.origin)
    setSize(frame.size)
  }

  func setTopLeft(_ topLeft: CGPoint) {
    app.enhancedUIWorkaround {
      var val = topLeft
      let value = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
      AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }
  }

  func setSize(_ size: CGSize) {
    app.enhancedUIWorkaround {
      var val = size
      let value = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
      AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }
  }

  func setFullScreen(_ value: Bool) {
    AXUIElementSetAttributeValue(element, kAXFullScreenAttribute as CFString, value as CFTypeRef)
  }

  func minimize() {
    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, true as CFTypeRef)
  }

  func unminimize() {
    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, false as CFTypeRef)
  }

  func focus() {
    if AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue) != .success {
      return
    }

    if let app = NSRunningApplication(processIdentifier: pid()) {
      app.activate()
    }
  }

  func spaces() -> [Space] {
    Space.spaces(for: self)
  }
}
