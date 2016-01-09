import JavaScriptCore

@objc protocol HotKeyJSExport: JSExport {
    var key: String { get }
    var modifiers: [String] { get }

    func enable() -> Bool
    func disable() -> Bool
}

extension HotKey: HotKeyJSExport { }