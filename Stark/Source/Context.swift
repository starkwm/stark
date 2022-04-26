import AppKit
import JavaScriptCore

class Context {
    var context: JSContext?
    var config: Config

    init(config: Config) {
        self.config = config
    }

    func setup() {
        guard let libPath = Bundle.main.path(forResource: "library", ofType: "js") else {
            fatalError("Could not find library.js")
        }

        setupAPI()

        loadJSFile(path: libPath)

        if FileManager.default.fileExists(atPath: config.primaryConfigPath) {
            loadJSFile(path: config.primaryConfigPath)
        }
    }

    func setupAPI() {
        context = JSContext(virtualMachine: JSVirtualMachine())

        guard let context = context else {
            fatalError("Could not setup JavaScript virtual machine")
        }

        if UserDefaults.standard.bool(forKey: logJavaScriptExceptionsKey) {
            context.exceptionHandler = { _, err in
                LogHelper.log(message: String(format: "Error: unhandled JavaScript exception (%@)", err!))
            }
        }

        context.setObject(Stark.self(config: config, context: self),
                          forKeyedSubscript: "Stark" as (NSCopying & NSObjectProtocol))

        context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as (NSCopying & NSObjectProtocol))

        context.setObject(App.self, forKeyedSubscript: "App" as (NSCopying & NSObjectProtocol))
        context.setObject(Window.self, forKeyedSubscript: "Window" as (NSCopying & NSObjectProtocol))
        context.setObject(Space.self, forKeyedSubscript: "Space" as (NSCopying & NSObjectProtocol))

        context.setObject(Bind.self, forKeyedSubscript: "Bind" as (NSCopying & NSObjectProtocol))
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
