import AppKit
import JavaScriptCore

@objc
protocol StarkJSExport: JSExport {
    func log(_ message: String)
    func reload()
    func run(_ command: String, _ arguments: [String]?)
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

    open func run(_ command: String, _ arguments: [String]?) {
        if !FileManager.default.fileExists(atPath: command) {
            LogHelper.log(message: String(format: "Binary '%@' doesn't exist", command))
            return
        }

        let task = Process()
        task.launchPath = command
        task.arguments = arguments
        task.launch()
    }
}
