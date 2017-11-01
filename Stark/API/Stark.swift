import AppKit
import JavaScriptCore

@objc
protocol StarkJSExport: JSExport {
    func log(_ message: String)
    func reload()
}

open class Stark: NSObject, StarkJSExport {
    private var config: Config
    private var context: Context

    init(config: Config, context: Context) {
        self.config = config
        self.context = context
    }

    open func log(_ message: String) {
        LogHelper.log(message: message)
    }

    open func reload() {
        context.setup()
    }
}
