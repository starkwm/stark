import JavaScriptCore

@objc
protocol BindJSExport: JSExport {
    init(key: String, modifiers: [String], callback: JSValue)

    var id: Int { get }

    var key: String { get }
    var modifiers: [String] { get }

    var isEnabled: Bool { get }

    func enable() -> Bool
    func disable() -> Bool
}
