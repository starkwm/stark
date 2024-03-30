import JavaScriptCore

@objc
protocol KeymapJSExport: JSExport {
  init(key: String, modifiers: [String], callback: JSValue)

  var id: Int { get }

  var key: String { get }
  var modifiers: [String] { get }
}
