import AppKit
import JavaScriptCore

@objc
protocol StarkJSExport: JSExport {
    func log(_ message: String)
    func reload()
    func launch(_ application: String)
    func run(_ command: String, _ arguments: [String]?)
}

open class Stark: NSObject, StarkJSExport {
    fileprivate var config: Config
    fileprivate var context: Context

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

    open func launch(_ application: String) {
        NSWorkspace.shared.launchApplication(application)
    }

    open func run(_ command: String, _ arguments: [String]?) {
        if !FileManager.default.fileExists(atPath: command) {
            LogHelper.log(message: String(format: "Binary '%@' doesn't exist", command))
            return
        }

        let task = Process()
        task.launchPath = command
        task.arguments = arguments

        task.waitUntilExit()
        task.launch()
    }
}
