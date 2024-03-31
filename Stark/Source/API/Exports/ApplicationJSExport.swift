import JavaScriptCore

@objc
/// The API for Application exported to the JavaScript environment.
protocol ApplicationJSExport: JSExport {
  static func find(_ name: String) -> Application?
  static func all() -> [Application]
  static func focused() -> Application?

  var name: String { get }

  var bundleID: String { get }
  var processID: pid_t { get }

  var isActive: Bool { get }
  var isHidden: Bool { get }
  var isTerminated: Bool { get }

  func windows(_ options: [String: AnyObject]) -> [Window]

  func activate() -> Bool
  func focus() -> Bool

  func show() -> Bool
  func hide() -> Bool

  func terminate() -> Bool
}
