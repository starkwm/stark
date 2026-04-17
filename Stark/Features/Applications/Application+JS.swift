import JavaScriptCore

@objc
protocol ApplicationJSExport: JSExport {
  static func all() -> [Application]
  static func focused() -> Application?
  static func find(_ name: String) -> Application?

  var name: String? { get }
  var bundleID: String? { get }
  var processID: pid_t { get }

  var isFrontmost: Bool { get }
  var isHidden: Bool { get }
  var isTerminated: Bool { get }

  func windows() -> [Window]
  func activate() -> Bool
  func focus() -> Bool
  func show() -> Bool
  func hide() -> Bool
  func terminate() -> Bool
}

extension Application: ApplicationJSExport {}
