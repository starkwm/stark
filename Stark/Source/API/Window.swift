import AppKit
import JavaScriptCore

// XXX: Undocumented private attribute for full screen mode
private let kAXFullScreenAttribute = "AXFullScreen"

private let starkVisibilityOptionsKey = "visible"

public class Window: NSObject, WindowJSExport {
  private static let systemWideElement = AXUIElementCreateSystemWide()

  public static func all(_ options: [String: AnyObject] = [:]) -> [Window] {
    Application.all().flatMap { $0.windows(options) }
  }

  public static func focused() -> Window? {
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

  init(element: AXUIElement) {
    self.element = element
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let window = object as? Self else {
      return false
    }

    return identifier == window.identifier
  }

  private var element: AXUIElement

  public var identifier: CGWindowID {
    var identifier: CGWindowID = 0
    _AXUIElementGetWindow(element, &identifier)
    return identifier
  }

  public var app: Application {
    Application(pid: pid())
  }

  public var screen: NSScreen {
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

  public var title: String {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) != .success {
      return ""
    }

    if let title = value as? String {
      return title
    }

    return ""
  }

  public var frame: CGRect {
    CGRect(origin: topLeft, size: size)
  }

  public var topLeft: CGPoint {
    var value: AnyObject?
    var topLeft = CGPoint.zero

    if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success {
      if !AXValueGetValue(value as! AXValue, AXValueType.cgPoint, &topLeft) {
        topLeft = CGPoint.zero
      }
    }

    return topLeft
  }

  public var size: CGSize {
    var value: AnyObject?
    var size = CGSize.zero

    if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success {
      if !AXValueGetValue(value as! AXValue, AXValueType.cgSize, &size) {
        size = CGSize.zero
      }
    }

    return size
  }

  public var isMain: Bool {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXMainAttribute as CFString, &value) != .success {
      return false
    }

    if let number = value as? NSNumber {
      return number.boolValue
    }

    return false
  }

  public var isStandard: Bool {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value) != .success {
      return false
    }

    if let subrole = value as? String {
      return subrole == kAXStandardWindowSubrole
    }

    return false
  }

  public var isFullscreen: Bool {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXFullScreenAttribute as CFString, &value) != .success {
      return false
    }

    if let number = value as? NSNumber {
      return number.boolValue
    }

    return false
  }

  public var isMinimized: Bool {
    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value) != .success {
      return false
    }

    if let number = value as? NSNumber {
      return number.boolValue
    }

    return false
  }

  public func setFrame(_ frame: CGRect) {
    let enhancedUserInterfaceEnabled = app.isEnhancedUserInterfaceEnabled() ?? false

    if enhancedUserInterfaceEnabled {
      app.disableEnhancedUserInterface()
    }

    setTopLeft(frame.origin)
    setSize(frame.size)

    if enhancedUserInterfaceEnabled {
      app.enableEnhancedUserInterface()
    }
  }

  public func setTopLeft(_ topLeft: CGPoint) {
    var val = topLeft
    let value = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
    AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
  }

  public func setSize(_ size: CGSize) {
    var val = size
    let value = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
    AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
  }

  public func setFullScreen(_ value: Bool) {
    AXUIElementSetAttributeValue(element, kAXFullScreenAttribute as CFString, value as CFTypeRef)
  }

  public func minimize() {
    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, true as CFTypeRef)
  }

  public func unminimize() {
    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, false as CFTypeRef)
  }

  public func focus() {
    if AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue) != .success {
      return
    }

    if let app = NSRunningApplication(processIdentifier: pid()) {
      app.activate()
    }
  }

  public func spaces() -> [Space] {
    Space.spaces(for: self)
  }

  private func pid() -> pid_t {
    var pid: pid_t = 0
    let result = AXUIElementGetPid(element, &pid)

    if result != .success {
      return 0
    }

    return pid
  }
}
