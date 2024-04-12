import AppKit
import JavaScriptCore

@objc protocol NSScreenJSExport: JSExport {
  static func all() -> [NSScreen]
  static func focused() -> NSScreen?

  var id: String { get }
  var flippedFrame: CGRect { get }
  var flippedVisibleFrame: CGRect { get }
  var next: NSScreen? { get }
  var previous: NSScreen? { get }

  func spaces() -> [Space]
  func currentSpace() -> Space?
}

extension NSScreen: NSScreenJSExport {}

extension NSScreen {
  static func all() -> [NSScreen] {
    screens
  }

  static func focused() -> NSScreen? {
    main
  }

  static func screen(for id: String) -> NSScreen? {
    screens.first { $0.id == id }
  }

  var id: String {
    guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
      return ""
    }

    let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value).takeRetainedValue()
    return CFUUIDCreateString(nil, uuid) as String
  }

  var flippedFrame: CGRect {
    let primaryScreen = NSScreen.screens.first
    var frame = frame
    frame.origin.y = primaryScreen!.frame.height - frame.height - frame.origin.y
    return frame
  }

  var flippedVisibleFrame: CGRect {
    let primaryScreen = NSScreen.screens.first
    var frame = visibleFrame
    frame.origin.y = primaryScreen!.frame.height - frame.height - frame.origin.y
    return frame
  }

  var next: NSScreen? {
    guard let currentIndex = NSScreen.screens.firstIndex(of: self) else {
      return nil
    }

    let nextIndex = (currentIndex + 1) % NSScreen.screens.count

    return NSScreen.screens[nextIndex]
  }

  var previous: NSScreen? {
    guard let currentIndex = NSScreen.screens.firstIndex(of: self) else {
      return nil
    }

    let previousIndex = (currentIndex == 0) ? NSScreen.screens.count - 1 : currentIndex - 1

    return NSScreen.screens[previousIndex]
  }

  func spaces() -> [Space] {
    Space.all().filter { $0.screens().contains(self) }
  }

  func currentSpace() -> Space? {
    Space.current(for: self)
  }
}
