import AppKit
import JavaScriptCore

/// Protocol exposing screen/display functionality to JavaScript.
/// Provides access to physical screens and their properties.
@objc protocol NSScreenJSExport: JSExport {
  // MARK: - Screen Retrieval

  /// Returns all connected screens.
  /// - Returns: Array of all screens
  static func all() -> [NSScreen]

  /// Returns the main (focused) screen.
  /// - Returns: The main screen, or nil if none
  static func focused() -> NSScreen?

  // MARK: - Properties

  /// Unique identifier for this screen.
  var id: String { get }

  /// Screen frame with origin at top-left (flipped coordinates).
  /// Use this for window positioning calculations.
  var flippedFrame: CGRect { get }

  /// Visible frame (excluding menu bar/dock) with origin at top-left.
  var flippedVisibleFrame: CGRect { get }

  /// The next screen in the sequence (for multi-monitor setups).
  var next: NSScreen? { get }

  /// The previous screen in the sequence (for multi-monitor setups).
  var previous: NSScreen? { get }

  // MARK: - Space Methods

  /// Returns all spaces on this screen.
  /// - Returns: Array of spaces
  func spaces() -> [Space]

  /// Returns the currently active space on this screen.
  /// - Returns: The current space, or nil if none
  func currentSpace() -> Space?
}

extension AppKit.NSScreen: JavaScriptCore.JSExport {}

extension NSScreen: NSScreenJSExport {
  /// Returns the current list of connected screens.
  static func all() -> [NSScreen] {
    screens
  }

  /// Returns the main AppKit screen.
  static func focused() -> NSScreen? {
    main
  }

  /// Looks up a screen by its stable display UUID string.
  static func screen(for id: String) -> NSScreen? {
    screens.first { $0.id == id }
  }

  var id: String {
    guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    else { return "" }

    let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value).takeRetainedValue()
    return CFUUIDCreateString(nil, uuid) as String
  }

  var flippedFrame: CGRect {
    guard let primaryScreen = NSScreen.screens.first else { return CGRect.zero }

    var frame = frame
    frame.origin.y = primaryScreen.frame.height - frame.height - frame.origin.y

    return frame
  }

  var flippedVisibleFrame: CGRect {
    guard let primaryScreen = NSScreen.screens.first else { return CGRect.zero }

    var frame = visibleFrame
    frame.origin.y = primaryScreen.frame.height - frame.height - frame.origin.y

    return frame
  }

  var next: NSScreen? {
    guard let currentIndex = NSScreen.screens.firstIndex(of: self) else { return nil }

    let nextIndex = (currentIndex + 1) % NSScreen.screens.count

    return NSScreen.screens[nextIndex]
  }

  var previous: NSScreen? {
    guard let currentIndex = NSScreen.screens.firstIndex(of: self) else { return nil }

    let previousIndex = (currentIndex == 0) ? NSScreen.screens.count - 1 : currentIndex - 1

    return NSScreen.screens[previousIndex]
  }

  /// Returns every space whose screen list currently includes this screen.
  func spaces() -> [Space] {
    Space.all().filter { $0.screens().contains(self) }
  }

  /// Returns the space currently shown on this screen.
  func currentSpace() -> Space? {
    Space.current(for: self)
  }
}
