import AppKit
import JavaScriptCore

class Context {
    var context: JSContext?
    var config: Config

    init(config: Config) {
        self.config = config
    }

    func setup() {
        guard let bindLibPath = Bundle.main.path(forResource: "bind", ofType: "js") else {
            fatalError("Could not find bind.js")
        }

        guard let eventLibPath = Bundle.main.path(forResource: "event", ofType: "js") else {
            fatalError("Could not find event.js")
        }

        guard let taskLibPath = Bundle.main.path(forResource: "task", ofType: "js") else {
            fatalError("Could not find task.js")
        }

        guard let timerLibPath = Bundle.main.path(forResource: "timer", ofType: "js") else {
            fatalError("Could not find timer.js")
        }

        config.createUnlessExists()

        setupAPI()

        loadJSFile(path: bindLibPath)
        loadJSFile(path: eventLibPath)
        loadJSFile(path: taskLibPath)
        loadJSFile(path: timerLibPath)
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
