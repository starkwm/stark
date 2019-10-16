import AppKit
import JavaScriptCore

@objc
protocol TaskJSExport: JSExport {
    init(path: String, arguments: [String]?, callback: JSValue?)

    var id: Int { get }

    var status: Int { get }

    func terminate()
}
