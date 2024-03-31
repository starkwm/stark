import AppKit
import JavaScriptCore

private let starkVisibilityOptionsKey = "visible"

private let screenIDKey = "Display Identifier"
private let spaceIDKey = "ManagedSpaceID"
private let spacesKey = "Spaces"

public class Space: NSObject, SpaceJSExport {
  private static let connectionID = SLSMainConnectionID()

  public static func all() -> [Space] {
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

  public static func at(_ index: Int) -> Space? {
    all()[index]
  }

  public static func active() -> Space {
    Space(id: SLSGetActiveSpace(connectionID))
  }

  static func current(for screen: NSScreen) -> Space? {
    let id = SLSManagedDisplayGetCurrentSpace(connectionID, screen.id as CFString)

    return Space(id: id)
  }

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

  public var id: uint64

  public var isNormal: Bool {
    SLSSpaceGetType(Self.connectionID, id) == 0
  }

  public var isFullscreen: Bool {
    SLSSpaceGetType(Self.connectionID, id) == 4
  }

  init(id: uint64) {
    self.id = id
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let space = object as? Self else {
      return false
    }

    return id == space.id
  }

  public func screens() -> [NSScreen] {
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

  public func windows(_ options: [String: AnyObject] = [:]) -> [Window] {
    Window.all(options).filter { $0.spaces().contains(self) }
  }

  public func moveWindow(_ window: Window) {
    moveWindows([window])
  }

  public func moveWindows(_ windows: [Window]) {
    SLSMoveWindowsToManagedSpace(Self.connectionID, windows.map(\.id) as CFArray, id)
  }
}
