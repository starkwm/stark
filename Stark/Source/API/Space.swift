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

    for info in displaySpacesInfo {
      guard let spacesInfo = info as? [String: AnyObject] else {
        continue
      }

      guard let identifiers = spacesInfo[spacesKey] as? [[String: AnyObject]] else {
        continue
      }

      for identifier in identifiers {
        guard let identifier = identifier[spaceIDKey] as? uint64 else {
          continue
        }

        spaces.append(Space(identifier: identifier))
      }
    }

    return spaces
  }

  public static func at(_ index: Int) -> Space? {
    all()[index]
  }

  public static func active() -> Space {
    Space(identifier: SLSGetActiveSpace(connectionID))
  }

  static func current(for screen: NSScreen) -> Space? {
    let identifier = SLSManagedDisplayGetCurrentSpace(connectionID, screen.id as CFString)

    return Space(identifier: identifier)
  }

  static func spaces(for window: Window) -> [Space] {
    var spaces: [Space] = []

    let identifiers =
      SLSCopySpacesForWindows(
        connectionID,
        7,
        [window.id] as CFArray
      ).takeRetainedValue() as NSArray

    for space in all() {
      if identifiers.contains(space.identifier) {
        spaces.append(Space(identifier: space.identifier))
      }
    }

    return spaces
  }

  public var identifier: uint64

  public var isNormal: Bool {
    SLSSpaceGetType(Self.connectionID, identifier) == 0
  }

  public var isFullscreen: Bool {
    SLSSpaceGetType(Self.connectionID, identifier) == 4
  }

  init(identifier: uint64) {
    self.identifier = identifier
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let space = object as? Self else {
      return false
    }

    return identifier == space.identifier
  }

  public func screens() -> [NSScreen] {
    if !NSScreen.screensHaveSeparateSpaces {
      return NSScreen.screens
    }

    let displaySpacesInfo = SLSCopyManagedDisplaySpaces(Self.connectionID).takeRetainedValue() as NSArray

    var screen: NSScreen?

    for info in displaySpacesInfo {
      guard let spacesInfo = info as? [String: AnyObject] else {
        continue
      }

      guard let screenIdentifier = spacesInfo[screenIDKey] as? String else {
        continue
      }

      guard let identifiers = spacesInfo[spacesKey] as? [[String: AnyObject]] else {
        continue
      }

      for identifier in identifiers {
        guard let identifier = identifier[spaceIDKey] as? uint64 else {
          continue
        }

        if identifier == self.identifier {
          screen = NSScreen.screen(for: screenIdentifier)
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
    SLSMoveWindowsToManagedSpace(Self.connectionID, windows.map(\.id) as CFArray, identifier)
  }
}
