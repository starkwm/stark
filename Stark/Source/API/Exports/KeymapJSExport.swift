import JavaScriptCore

@objc
protocol KeymapJSExport: JSExport {
  var id: Int { get }

  var key: String { get }
  var modifiers: [String] { get }

  init(key: String, modifiers: [String], callback: JSValue)
}
