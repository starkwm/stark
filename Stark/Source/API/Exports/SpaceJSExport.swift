import AppKit
import JavaScriptCore

@objc
protocol SpaceJSExport: JSExport {
  static func all() -> [Space]
  static func at(_ index: Int) -> Space?
  static func active() -> Space

  var identifier: uint64 { get }

  var isNormal: Bool { get }
  var isFullscreen: Bool { get }

  func screens() -> [NSScreen]

  func windows(_ options: [String: AnyObject]) -> [Window]

  func addWindows(_ windows: [Window])
  func removeWindows(_ windows: [Window])
  func moveWindows(_ windows: [Window])
}
