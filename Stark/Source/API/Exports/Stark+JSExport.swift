import JavaScriptCore

@objc
protocol StarkJSExport: JSExport {
    func log(_ message: String)
    func reload()
    func run(_ command: String, _ arguments: [String]?)
}
