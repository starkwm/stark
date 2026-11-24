import AppKit

class Space: NSObject {
  static let connection = windowServerClient.mainConnectionID()

  private static let windowServerClient = WindowServerClient.live

  static func all() -> [Space] {
    windowServerClient.allSpaces().map { Space(id: $0.id.rawValue, type: SpaceType($0.type)) }
  }

  static func at(_ index: Int) -> Space? {
    let spaces = all()

    guard spaces.indices.contains(index) else { return nil }

    return spaces[index]
  }

  static func active() -> Space {
    Space(id: windowServerClient.activeSpace())
  }

  static func current(for screen: NSScreen) -> Space? {
    Space(id: windowServerClient.currentSpace(screenID: screen.id))
  }

  static func spaces(containing window: Window) -> [Space] {
    let identifiers = Set(
      windowServerClient.spaceIDs(containing: window.id)
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

  convenience init(id: UInt64) {
    self.init(id: id, type: Self.windowServerClient.spaceType(for: id))
  }

  init(id: UInt64, type: SpaceType) {
    self.id = id
    self.type = type
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
      let screenID = Self.windowServerClient.screenID(forSpaceID: id),
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
