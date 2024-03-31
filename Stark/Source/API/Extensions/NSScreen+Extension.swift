private let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

/// Extends the NSScreen class.
extension NSScreen: NSScreenJSExport {
  /// Get all the screens.
  public static func all() -> [NSScreen] {
    screens
  }

  /// Get the focused screen.
  public static func focused() -> NSScreen? {
    main
  }

  /// Get the screen with the given identifier.
  static func screen(for id: String) -> NSScreen? {
    screens.first { $0.id == id }
  }

  /// The identifier for the screen.
  public var id: String {
    guard let number = deviceDescription[screenNumberKey] as? NSNumber else {
      return ""
    }

    let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value).takeRetainedValue()
    return CFUUIDCreateString(nil, uuid) as String
  }

  /// The frame for screen with the top left point at 0,0.
  public var flippedFrame: CGRect {
    let primaryScreen = NSScreen.screens.first
    var frame = frame
    frame.origin.y = primaryScreen!.frame.height - frame.height - frame.origin.y
    return frame
  }

  /// The frame for the screen with the top left point at 0,0, but excluding the menu bar and dock space.
  public var flippedVisibleFrame: CGRect {
    let primaryScreen = NSScreen.screens.first
    var frame = visibleFrame
    frame.origin.y = primaryScreen!.frame.height - frame.height - frame.origin.y
    return frame
  }

  /// The next screen.
  public var next: NSScreen? {
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
  public var previous: NSScreen? {
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

  /// Get the current space for the screen.
  public func currentSpace() -> Space? {
    Space.current(for: self)
  }

  /// Get all the spaces for the screen.
  public func spaces() -> [Space] {
    Space.all().filter { $0.screens().contains(self) }
  }
}
