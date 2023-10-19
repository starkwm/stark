import JavaScriptCore

@objc
protocol StarkJSExport: JSExport {
    func log(_ message: String)
    func reload()
}
