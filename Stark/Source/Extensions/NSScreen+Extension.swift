import JavaScriptCore

/// The protocol for the exported attributes of NSScreen.
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
  /// Get all available screens.
  static func all() -> [NSScreen] {
    screens
  }

  /// Get the screen with keyboard focus.
  static func focused() -> NSScreen? {
    main
  }

  /// Get the screen with the given identifier.
  static func screen(for id: String) -> NSScreen? {
    screens.first { $0.id == id }
  }

  /// The identifier for the screen.
  var id: String {
    guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
      return ""
    }

    let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value).takeRetainedValue()
    return CFUUIDCreateString(nil, uuid) as String
  }

  /// The frame for screen with the top left coords at 0,0.
  var flippedFrame: CGRect {
    let primaryScreen = NSScreen.screens.first
    var frame = frame
    frame.origin.y = primaryScreen!.frame.height - frame.height - frame.origin.y
    return frame
  }

  /// The frame for the screen with the top left coords at 0,0, but excluding the menu bar and dock space.
  var flippedVisibleFrame: CGRect {
    let primaryScreen = NSScreen.screens.first
    var frame = visibleFrame
    frame.origin.y = primaryScreen!.frame.height - frame.height - frame.origin.y
    return frame
  }

  /// The next screen.
  var next: NSScreen? {
    let screens = NSScreen.screens

    if var index = screens.firstIndex(of: self) {
      index += 1

      if index == screens.count {
        index = 0
      }

      return screens[index]
    }

    return nil
  }

  /// The previous screen.
  var previous: NSScreen? {
    let screens = NSScreen.screens

    if var index = screens.firstIndex(of: self) {
      index -= 1

      if index == -1 {
        index = screens.count - 1
      }

      return screens[index]
    }

    return nil
  }

  /// Get all the spaces for the screen.
  func spaces() -> [Space] {
    Space.all().filter { $0.screens().contains(self) }
  }

  /// Get the current space for the screen.
  func currentSpace() -> Space? {
    Space.current(for: self)
  }
}
