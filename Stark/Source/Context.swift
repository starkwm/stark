import AppKit
import JavaScriptCore

class Context {
    let observer = RunningAppsObserver()

    var context: JSContext?
    var config: Config

    init(config: Config) {
        self.config = config
    }

    func setup() {
        guard let starklibPath = Bundle.main.path(forResource: "stark-lib", ofType: "js") else {
            fatalError("Could not find stark-lib.js")
        }

        config.createUnlessExists(path: config.primaryConfigPath)

        setupAPI()

        loadJSFile(path: starklibPath)
        loadJSFile(path: config.primaryConfigPath)
    }

    func setupAPI() {
        context = JSContext(virtualMachine: JSVirtualMachine())

        guard let context = context else {
            fatalError("Could not setup JavaScript virtual machine")
        }

        context.exceptionHandler = { _, err in
            LogHelper.log(message: String(format: "Error: unhandled JavaScript exception (%@)", err!))
        }

        context.setObject(Stark.self(config: config, context: self),
                          forKeyedSubscript: "Stark" as (NSCopying & NSObjectProtocol))

        context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as (NSCopying & NSObjectProtocol))

        context.setObject(Application.self, forKeyedSubscript: "App" as (NSCopying & NSObjectProtocol))
        context.setObject(Window.self, forKeyedSubscript: "Window" as (NSCopying & NSObjectProtocol))
        context.setObject(Space.self, forKeyedSubscript: "Space" as (NSCopying & NSObjectProtocol))

        context.setObject(Bind.self, forKeyedSubscript: "Bind" as (NSCopying & NSObjectProtocol))
        context.setObject(Event.self, forKeyedSubscript: "Event" as (NSCopying & NSObjectProtocol))
        context.setObject(Task.self, forKeyedSubscript: "Task" as (NSCopying & NSObjectProtocol))
        context.setObject(Timer.self, forKeyedSubscript: "Timer" as (NSCopying & NSObjectProtocol))
    }

    func loadJSFile(path: String) {
        guard let scriptContents = try? String(contentsOfFile: path) else {
            fatalError(String(format: "Could not read script (%@)", path))
        }

        guard let context = context else {
            fatalError("Could not setup JavaScript virtual machine")
        }

        context.evaluateScript(scriptContents)
    }
}
