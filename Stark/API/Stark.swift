import AppKit
import JavaScriptCore

@objc protocol StarkJSExport: JSExport {
    func log(_ message: String)
    func reload()
    func launch(_ application: String)
    @objc(run::) func run(_ command: String, arguments: [String]?)
}

open class Stark: NSObject, StarkJSExport {
    fileprivate var config: Config
    fileprivate var context: Context

    init(config: Config, context: Context) {
        self.config = config
        self.context = context
    }

    open func log(_ message: String) {
        LogHelper.log(message)
    }

    open func reload() {
        context.setup()
    }

    open func launch(_ application: String) {
        NSWorkspace.shared().launchApplication(application)
    }

    @objc(run::) open func run(_ command: String, arguments: [String]?) {
        let task = Process()
        task.launchPath = command
        task.arguments = arguments
        task.launch()
        task.waitUntilExit()
    }
}
