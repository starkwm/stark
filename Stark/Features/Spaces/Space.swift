import AppKit
import JavaScriptCore

/// Protocol exposing Space (virtual desktop) functionality to JavaScript.
/// Provides access to macOS Spaces and their windows.
@objc protocol SpaceJSExport: JSExport {
  // MARK: - Space Retrieval

  /// Returns all Spaces across all screens.
  /// - Returns: Array of all spaces
  static func all() -> [Space]

  /// Returns the Space at the specified index.
  /// - Parameter index: The zero-based index
  /// - Returns: The space at that index, or nil if out of bounds
  static func at(_ index: Int) -> Space?

  /// Returns the currently active Space.
  /// - Returns: The active space
  static func active() -> Space

  // MARK: - Properties

  /// Unique identifier for this space.
  var id: uint64 { get }

  /// Whether this is a normal space (not fullscreen).
  var isNormal: Bool { get }

  /// Whether this is a fullscreen space.
  var isFullscreen: Bool { get }

  // MARK: - Space Contents

  /// Returns all screens showing this space.
  /// - Returns: Array of screens
  func screens() -> [NSScreen]

  /// Returns all windows in this space.
  /// - Returns: Array of windows
  func windows() -> [Window]
}

class Space: NSObject, SpaceJSExport {
  private static let windowServerClient = WindowServerClient.live

  static let connection = windowServerClient.mainConnectionID()

  static func all() -> [Space] {
    windowServerClient.allSpaceIDs(connectionID: connection).map(Space.init(id:))
  }

  static func at(_ index: Int) -> Space? {
    let spaces = all()

    guard spaces.indices.contains(index) else { return nil }

    return spaces[index]
  }

  static func active() -> Space {
    Space(id: windowServerClient.activeSpace(connectionID: connection))
  }

  static func current(for screen: NSScreen) -> Space? {
    Space(id: windowServerClient.currentSpace(connectionID: connection, screenID: screen.id))
  }

  static func spaces(containing window: Window) -> [Space] {
    let identifiers = Set(
      windowServerClient.spaceIDs(containing: window.id, connectionID: connection)
    )
    return all().filter { identifiers.contains($0.id) }
  }

  override var description: String {
    "<Space id: \(id), type: \(type)>"
  }

  var id: UInt64

  var isNormal: Bool { type == .normal }

  var isFullscreen: Bool { type == .fullscreen }

  private var type: SpaceType

  init(id: uint64) {
    self.id = id
    type = Self.windowServerClient.spaceType(connectionID: Space.connection, spaceID: self.id)
  }

  deinit {
    log("space deinit \(self)")
  }

  override func isEqual(_ object: Any?) -> Bool {
    guard let space = object as? Self else { return false }

    return id == space.id
  }

  func screens() -> [NSScreen] {
    if !NSScreen.screensHaveSeparateSpaces {
      return NSScreen.screens
    }

    guard
      let screenID = Self.windowServerClient.screenID(
        forSpaceID: id,
        connectionID: Space.connection
      ),
      let screen = NSScreen.screen(for: screenID)
    else {
      return []
    }

    return [screen]
  }

  func windows() -> [Window] {
    Window.all().filter { $0.spaces().contains(self) }
  }
}
