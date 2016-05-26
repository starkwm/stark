import AppKit
import JavaScriptCore

@objc protocol StarkJSExport: JSExport {
    func log(message: String)
    func reload()
    @objc(bind:::) func bind(key: String, modifiers: [String], callback: JSValue) -> Bind
    @objc(on::) func on(event: String, callback: JSValue) -> Event
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

    @objc(bind:::) public func bind(key: String, modifiers: [String], callback: JSValue) -> Bind {
        return config.bindKey(key, modifiers: modifiers, callback: callback)
    }

    @objc(on::) public func on(event: String, callback: JSValue) -> Event {
        return Event(event: event, callback: callback)
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