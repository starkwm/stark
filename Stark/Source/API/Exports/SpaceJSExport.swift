import JavaScriptCore

@objc
/// The API for Space exported to the JavaScript environment.
protocol SpaceJSExport: JSExport {
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
