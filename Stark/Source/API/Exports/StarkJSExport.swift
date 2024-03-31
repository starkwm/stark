import JavaScriptCore

@objc
/// The API for Stark exported to the JavaScript environment.
protocol StarkJSExport: JSExport {
  func log(_ message: String)
  func reload()
}
