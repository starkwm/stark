import AppKit
import JavaScriptCore

public class Context {
    private var context: JSContext
    private var config: Config

    private let observer = RunningAppsObserver()

    public init(config: Config) {
        self.context = JSContext(virtualMachine: JSVirtualMachine())
        self.config = config
    }

    public func setup() {
        Bind.reset()

        setupAPI()

        guard let lodashPath = NSBundle.mainBundle().pathForResource("lodash-min", ofType: "js") else {
            LogHelper.log("Unable to setup context, could not find lodash-min.js")
            return
        }

        config.createUnlessExists(config.primaryConfigPath)

        loadJSFile(lodashPath)
        loadJSFile(config.primaryConfigPath)
    }

    private func handleJSException(exception: JSValue) {
        LogHelper.log(String(format: "Unhandled JavaScript Exception: %@", exception))
    }

    private func setupAPI() {
        context = JSContext(virtualMachine: JSVirtualMachine())

        context.exceptionHandler = { [weak self] ctx, exception in
            self?.handleJSException(exception)
        }

        context.setObject(Stark.self(config: config, context: self), forKeyedSubscript: "Stark")

        context.setObject(NSScreen.self, forKeyedSubscript: "Screen")

        context.setObject(Application.self, forKeyedSubscript: "App")
        context.setObject(Window.self, forKeyedSubscript: "Window")

        context.setObject(Bind.self, forKeyedSubscript: "Bind")
        context.setObject(Event.self, forKeyedSubscript: "Event")
        context.setObject(Timer.self, forKeyedSubscript: "Timer")
    }

    private func loadJSFile(path: String) {
        guard let scriptContents = try? String(contentsOfFile: path) else {
            LogHelper.log(String(format: "Unable to read script: %@", path))
            return
        }

        context.evaluateScript(scriptContents)
    }
}