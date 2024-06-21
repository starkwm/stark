import AppKit
import JavaScriptCore
import OSLog

private let systemWideElement = AXUIElementCreateSystemWide()

private let kAXFullScreenAttribute = "AXFullScreen"

@objc protocol WindowJSExport: JSExport {
  static func all() -> [Window]
  static func focused() -> Window?

  var id: CGWindowID { get }

  var application: Application? { get }
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
    return Array(WindowManager.shared.windows.values)
  }

  static func focused() -> Window? {
    var appElement: AnyObject?

    AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &appElement)

    if appElement == nil {
      return nil
    }

    var windowElement: AnyObject?

    let result = AXUIElementCopyAttributeValue(
      appElement as! AXUIElement,
      kAXFocusedWindowAttribute as CFString,
      &windowElement
    )

    if result != .success {
      return nil
    }

    let windowID = Window.id(for: windowElement as! AXUIElement)

    return WindowManager.shared.windows[windowID]
  }

  static func id(for element: AXUIElement) -> CGWindowID {
    var id: CGWindowID = 0
    _AXUIElementGetWindow(element, &id)
    return id
  }

  static func pid(for element: AXUIElement) -> pid_t? {
    var pid: pid_t = -1
    let result = AXUIElementGetPid(element, &pid)

    if result != .success {
      return nil
    }

    return pid
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
    guard let element = element else { return "" }

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
    guard let element = element else { return CGPoint.zero }

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
    guard let element = element else { return CGSize.zero }

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
    guard let element = element else { return false }

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
    guard let element = element else { return nil }

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
    guard let element = element else { return false }

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
    guard let element = element else { return false }

    var value: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value) != .success {
      return false
    }

    if let number = value as? NSNumber {
      return number.boolValue
    }

    return false
  }

  var element: AXUIElement?
  var application: Application?
  var id: CGWindowID

  private var observedNotifications = WindowNotifications(rawValue: 0)

  init(element: AXUIElement, application: Application) {
    self.element = element
    self.application = application
    self.id = Window.id(for: element)
  }

  deinit {
    Logger.main.debug("destroying window \(self, privacy: .public)")
  }

  private func pid() -> pid_t? {
    guard let element = element else { return nil }

    return Window.pid(for: element)
  }

  override func isEqual(_ object: Any?) -> Bool {
    guard let window = object as? Self else { return false }

    return id == window.id
  }

  func setFrame(_ frame: CGRect) {
    setSize(frame.size)
    setTopLeft(frame.origin)
    setSize(frame.size)
  }

  func setTopLeft(_ topLeft: CGPoint) {
    application?.enhancedUIWorkaround {
      guard let element = element else { return }

      var val = topLeft
      let value = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
      AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }
  }

  func setSize(_ size: CGSize) {
    application?.enhancedUIWorkaround {
      guard let element = element else { return }

      var val = size
      let value = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
      AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }
  }

  func setFullScreen(_ value: Bool) {
    guard let element = element else { return }

    AXUIElementSetAttributeValue(element, kAXFullScreenAttribute as CFString, value as CFTypeRef)
  }

  func minimize() {
    guard let element = element else { return }

    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, true as CFTypeRef)
  }

  func unminimize() {
    guard let element = element else { return }

    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, false as CFTypeRef)
  }

  func focus() {
    guard let element = element else { return }

    if AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue) != .success {
      return
    }

    guard let pid = pid() else { return }

    if let app = NSRunningApplication(processIdentifier: pid) {
      app.activate()
    }
  }

  func spaces() -> [Space] {
    Space.spaces(for: self)
  }

  func observe() -> Bool {
    guard let observer = application?.observer else { return false }
    guard let element = element else { return false }

    let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(self).toOpaque()

    for (idx, notification) in windowNotifications.enumerated() {
      let result = AXObserverAddNotification(observer, element, notification as CFString, context)

      if result == .success || result == .notificationAlreadyRegistered {
        observedNotifications.insert(WindowNotifications(rawValue: 1 << idx))
      } else {
        Logger.main.debug("notification \(notification, privacy: .public) not added \(self, privacy: .public)")
      }
    }

    return observedNotifications.contains(.all)
  }

  func unobserve() {
    guard let observer = application?.observer else { return }
    guard let element = element else { return }

    for (idx, notification) in windowNotifications.enumerated() {
      let notif = WindowNotifications(rawValue: 1 << idx)

      if observedNotifications.contains(notif) {
        AXObserverRemoveNotification(observer, element, notification as CFString)
        observedNotifications.remove(notif)
      }
    }
  }
}
