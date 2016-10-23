import AppKit
import JavaScriptCore

open class Context {
    fileprivate var context: JSContext
    fileprivate var config: Config

    fileprivate let observer = RunningAppsObserver()

    public init(config: Config) {
        context = JSContext(virtualMachine: JSVirtualMachine())
        self.config = config
    }

    open func setup() {
        Bind.reset()

        setupAPI()

        guard let lodashPath = Bundle.main.path(forResource: "lodash-min", ofType: "js") else {
            LogHelper.log("Unable to setup context, could not find lodash-min.js")
            return
        }

        guard let starklibPath = Bundle.main.path(forResource: "stark-lib", ofType: "js") else {
            LogHelper.log("Unable to setup context, could not find stark-lib.js")
            return
        }

        config.createUnlessExists(config.primaryConfigPath)

        loadJSFile(lodashPath)
        loadJSFile(starklibPath)
        loadJSFile(config.primaryConfigPath)
    }

    fileprivate func handleJSException(_ exception: JSValue) {
        LogHelper.log(String(format: "Unhandled JavaScript Exception: %@", exception))
    }

    fileprivate func setupAPI() {
        context = JSContext(virtualMachine: JSVirtualMachine())

        context.exceptionHandler = { [weak self] ctx, exception in
            self?.handleJSException(exception!)
        }

        context.setObject(Stark.self(config: config, context: self), forKeyedSubscript: "Stark" as (NSCopying & NSObjectProtocol)!)

        context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as (NSCopying & NSObjectProtocol)!)

        context.setObject(Application.self, forKeyedSubscript: "App" as (NSCopying & NSObjectProtocol)!)
        context.setObject(Window.self, forKeyedSubscript: "Window" as (NSCopying & NSObjectProtocol)!)

        context.setObject(Bind.self, forKeyedSubscript: "Bind" as (NSCopying & NSObjectProtocol)!)
        context.setObject(Event.self, forKeyedSubscript: "Event" as (NSCopying & NSObjectProtocol)!)
        context.setObject(Timer.self, forKeyedSubscript: "Timer" as (NSCopying & NSObjectProtocol)!)
    }

    fileprivate func loadJSFile(_ path: String) {
        guard let scriptContents = try? String(contentsOfFile: path) else {
            LogHelper.log(String(format: "Unable to read script: %@", path))
            return
        }

        context.evaluateScript(scriptContents)
    }
}
