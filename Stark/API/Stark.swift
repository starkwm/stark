import AppKit
import JavaScriptCore

@objc protocol StarkJSExport: JSExport {
    func log(message: String)
    func reload()
    func launch(application: String)
    @objc(run::) func run(command: String, arguments: [String]?)
}

public class Stark: NSObject, StarkJSExport {
    var config: Config

    init(config: Config) {
        self.config = config
    }

    public func log(message: String) {
        LogHelper.log(message)
    }

    public func reload() {
        config.load()
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