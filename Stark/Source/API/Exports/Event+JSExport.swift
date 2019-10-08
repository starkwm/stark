import JavaScriptCore

@objc
protocol EventJSExport: JSExport {
    init(event: String, callback: JSValue)

    var id: Int { get }

    var name: String { get }

    func disable()
}
