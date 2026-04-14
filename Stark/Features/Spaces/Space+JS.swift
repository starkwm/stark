import AppKit
import JavaScriptCore

@objc protocol SpaceJSExport: JSExport {
  static func all() -> [Space]
  static func at(_ index: Int) -> Space?
  static func active() -> Space

  var id: UInt64 { get }

  var isNormal: Bool { get }
  var isFullscreen: Bool { get }

  func screens() -> [NSScreen]
  func windows() -> [Window]
}

extension Space: SpaceJSExport {}
