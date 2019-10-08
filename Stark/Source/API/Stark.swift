import AppKit
import JavaScriptCore

public class Stark: NSObject, StarkJSExport {
    init(config: Config, context: Context) {
        self.config = config
        self.context = context
    }

    private var config: Config

    private var context: Context

    public func log(_ message: String) {
        LogHelper.log(message: message)
    }

    public func reload() {
        context.setup()
    }

    public func run(_ command: String, _ arguments: [String] = []) {
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
