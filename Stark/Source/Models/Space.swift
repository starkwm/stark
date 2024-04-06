import JavaScriptCore

/// The key for the screen identifier in the key/value results for display spaces.
private let screenIDKey = "Display Identifier"

/// The key for the space identifier in the key/value results for display spaces.
private let spaceIDKey = "ManagedSpaceID"

/// The key for the spaces in the key/value results for display spaces.
private let spacesKey = "Spaces"

/// The protocol for the exported attributes of Space.
@objc protocol SpaceJSExport: JSExport {
  static func all() -> [Space]
  static func at(_ index: Int) -> Space?
  static func active() -> Space

  var id: uint64 { get }

  var isNormal: Bool { get }
  var isFullscreen: Bool { get }

  func screens() -> [NSScreen]

  func windows(_ options: [String: AnyObject]) -> [Window]

  func moveWindow(_ window: Window)
  func moveWindows(_ windows: [Window])
}

/// Space represents a mission control space.
class Space: NSObject, SpaceJSExport {
  /// The connection identifier used to call private framework functions from SkyLight.
  private static let connectionID = SLSMainConnectionID()

  /// Get the current space for the given screen.
  static func current(for screen: NSScreen) -> Space? {
    let id = SLSManagedDisplayGetCurrentSpace(connectionID, screen.id as CFString)

    return Space(id: id)
  }

  /// Get the spaces that contain the given window.
  static func spaces(for window: Window) -> [Space] {
    var spaces: [Space] = []

    let identifiers =
      SLSCopySpacesForWindows(
        connectionID,
        0x7,
        [window.id] as CFArray
      ).takeRetainedValue() as NSArray

    for space in all() {
      if identifiers.contains(space.id) {
        spaces.append(Space(id: space.id))
      }
    }

    return spaces
  }

  /// Get all spaces.
  static func all() -> [Space] {
    var spaces: [Space] = []

    let displaySpacesInfo = SLSCopyManagedDisplaySpaces(connectionID).takeRetainedValue() as NSArray

    for item in displaySpacesInfo {
      guard let info = item as? [String: AnyObject] else {
        continue
      }

      guard let spacesInfo = info[spacesKey] as? [[String: AnyObject]] else {
        continue
      }

      for spaceInfo in spacesInfo {
        guard let id = spaceInfo[spaceIDKey] as? uint64 else {
          continue
        }

        spaces.append(Space(id: id))
      }
    }

    return spaces
  }

  /// Get the space at the given index.
  static func at(_ index: Int) -> Space? {
    all()[index]
  }

  /// Get the currently active space.
  static func active() -> Space {
    Space(id: SLSGetActiveSpace(connectionID))
  }

  /// The identifier for the space.
  var id: uint64

  /// Indicates if the space is a normal user space.
  var isNormal: Bool {
    // TODO: extract magic number into variable
    SLSSpaceGetType(Self.connectionID, id) == 0
  }

  /// Indicates if the space is a fullscreen application space.
  var isFullscreen: Bool {
    // TODO: extract magic number into variable
    SLSSpaceGetType(Self.connectionID, id) == 4
  }

  /// Initialise using the given identifier.
  init(id: uint64) {
    self.id = id
  }

  /// Check if the given variable matches this space instance.
  override func isEqual(_ object: Any?) -> Bool {
    guard let space = object as? Self else {
      return false
    }

    return id == space.id
  }

  /// Get the screens that this space belongs to.
  func screens() -> [NSScreen] {
    if !NSScreen.screensHaveSeparateSpaces {
      return NSScreen.screens
    }

    let displaySpacesInfo = SLSCopyManagedDisplaySpaces(Self.connectionID).takeRetainedValue() as NSArray

    var screen: NSScreen?

    for item in displaySpacesInfo {
      guard let info = item as? [String: AnyObject] else {
        continue
      }

      guard let screenID = info[screenIDKey] as? String else {
        continue
      }

      guard let spacesInfo = info[spacesKey] as? [[String: AnyObject]] else {
        continue
      }

      for spaceInfo in spacesInfo {
        guard let id = spaceInfo[spaceIDKey] as? uint64 else {
          continue
        }

        if id == self.id {
          screen = NSScreen.screen(for: screenID)
        }
      }
    }

    if screen == nil {
      return []
    }

    return [screen!]
  }

  /// Get all the windows contained on this space.
  func windows(_ options: [String: AnyObject] = [:]) -> [Window] {
    Window.all(options).filter { $0.spaces().contains(self) }
  }

  /// Move the given window to this space.
  func moveWindow(_ window: Window) {
    moveWindows([window])
  }

  /// Move the given windows to this space.
  func moveWindows(_ windows: [Window]) {
    SLSMoveWindowsToManagedSpace(Self.connectionID, windows.map(\.id) as CFArray, id)
  }
}
