import JavaScriptCore

@objc
/// The API for NSScreen exported to the JavaScript environment.
protocol NSScreenJSExport: JSExport {
  static func all() -> [NSScreen]
  static func focused() -> NSScreen?

  var id: String { get }

  var flippedFrame: CGRect { get }
  var flippedVisibleFrame: CGRect { get }

  var next: NSScreen? { get }
  var previous: NSScreen? { get }

  func currentSpace() -> Space?
  func spaces() -> [Space]
}
