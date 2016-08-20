import AppKit
import JavaScriptCore

@objc protocol StarkJSExport: JSExport {
    func log(message: String)
    func reload()
    func launch(application: String)
    @objc(run::) func run(command: String, arguments: [String]?)
}

public class Stark: NSObject, StarkJSExport {
    private var config: Config
    private var context: Context

    init(config: Config, context: Context) {
        self.config = config
        self.context = context
    }

    public func log(message: String) {
        LogHelper.log(message)
    }

    public func reload() {
        context.setup()
    }

    public func launch(application: String) {
        NSWorkspace.sharedWorkspace().launchApplication(application)
    }

    @objc(run::) public func run(command: String, arguments: [String]?) {
        let task = NSTask()
        task.launchPath = command
        task.arguments = arguments
        task.launch()
        task.waitUntilExit()
    }
}
