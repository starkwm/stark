import AppKit
import JavaScriptCore

private let screenIDKey = "Display Identifier"
private let spaceIDKey = "ManagedSpaceID"
private let spacesKey = "Spaces"

@objc protocol SpaceJSExport: JSExport {
  static func all() -> [Space]
  static func at(_ index: Int) -> Space?
  static func active() -> Space

  var id: uint64 { get }

  var isNormal: Bool { get }
  var isFullscreen: Bool { get }

  func screens() -> [NSScreen]

  func windows() -> [Window]

  func moveWindow(_ window: Window)
}

extension Space: SpaceJSExport {}

extension Space {
  override var description: String {
    "<Space id: \(id), type: \(type)>"
  }
}

class Space: NSObject {
  static let connection = SLSMainConnectionID()

  static func current(for screen: NSScreen) -> Space? {
    let id = SLSManagedDisplayGetCurrentSpace(connection, screen.id as CFString)

    return Space(id: id)
  }

  static func spaces(for window: Window) -> [Space] {
    let identifiers =
      SLSCopySpacesForWindows(
        connection,
        0x7,
        [window.id] as CFArray
      ) as NSArray

    var spaces: [Space] = []

    for space in all() {
      if identifiers.contains(space.id) {
        spaces.append(space)
      }
    }

    return spaces
  }

  static func all() -> [Space] {
    var spaces: [Space] = []

    let displaySpacesInfo = SLSCopyManagedDisplaySpaces(connection) as NSArray

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

  static func at(_ index: Int) -> Space? {
    all()[index]
  }

  static func active() -> Space {
    Space(id: SLSGetActiveSpace(connection))
  }

  var id: UInt64

  var isNormal: Bool { type == 0 }

  var isFullscreen: Bool { type == 4 }

  private var type: Int32

  init(id: uint64) {
    self.id = id
    self.type = SLSSpaceGetType(Space.connection, self.id)
  }

  override func isEqual(_ object: Any?) -> Bool {
    guard let space = object as? Self else {
      return false
    }

    return id == space.id
  }

  func screens() -> [NSScreen] {
    if !NSScreen.screensHaveSeparateSpaces {
      return NSScreen.screens
    }

    let displaySpacesInfo = SLSCopyManagedDisplaySpaces(Space.connection) as NSArray

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

  func windows() -> [Window] {
    Window.all().filter { $0.spaces().contains(self) }
  }

  func moveWindow(_ window: Window) {
    _ = SLSSpaceSetCompatID(Space.connection, id, 0x79616265)
    _ = withUnsafeMutablePointer(to: &window.id, { pointer -> CGError in
      return SLSSetWindowListWorkspace(Space.connection, pointer, 1, 0x79616265)
    })
    _ = SLSSpaceSetCompatID(Space.connection, id, 0x0)
  }
}
