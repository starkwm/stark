import AppKit
import JavaScriptCore

@objc protocol WindowJSExport: JSExport {
  static func all() -> [Window]
  static func focused() -> Window?

  var id: CGWindowID { get }
  var application: Application? { get }
  var screen: NSScreen? { get }
  var title: String { get }

  var frame: CGRect { get }
  var topLeft: CGPoint { get }
  var size: CGSize { get }

  var isStandard: Bool { get }
  var isMain: Bool { get }
  var isFullscreen: Bool { get }
  var isMinimized: Bool { get }

  func setFrame(_ frame: CGRect)
  func setTopLeft(_ topLeft: CGPoint)
  func setSize(_ size: CGSize)
  func setFullscreen(_ value: Bool)

  func minimize()
  func unminimize()
  func focus()
  func spaces() -> [Space]
}

extension Window: WindowJSExport {}
