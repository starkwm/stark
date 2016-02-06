import AppKit
import JavaScriptCore

public class Config {
    private static let primaryConfigPaths: [String] = [
        "~/.stark.js",
        "~/Library/Application Support/Stark/stark.js",
        "~/.config/stark/stark.js",
    ]

    private var primaryConfigPath: String
    private var context: JSContext

    private var hotkeys: [Int: HotKey]

    private static func resolvePrimaryConfigPath() -> String {
        for primaryConfigPath in primaryConfigPaths {
            let resolvedConfigPath = (primaryConfigPath as NSString).stringByResolvingSymlinksInPath

            if NSFileManager.defaultManager().fileExistsAtPath(resolvedConfigPath) {
                return resolvedConfigPath
            }
        }

        return primaryConfigPaths.first!
    }

    public init() {
        primaryConfigPath = Config.resolvePrimaryConfigPath()
        context = JSContext(virtualMachine: JSVirtualMachine())
        hotkeys = [Int: HotKey]()
    }

    public func load() {
        resetHotKeys()

        if !NSFileManager.defaultManager().fileExistsAtPath(primaryConfigPath) {
            createConfigFile(primaryConfigPath)
        }

        setupContext()
    }

    private func resetHotKeys() {
        hotkeys.forEach { $1.disable() }
        hotkeys.removeAll()
    }

    private func createConfigFile(path: String) {
        let resolvedPath = (path as NSString).stringByResolvingSymlinksInPath

        if !NSFileManager.defaultManager().createFileAtPath(resolvedPath, contents: nil, attributes: nil) {
            NSLog("Unable to create configuration file: %@", path)
        }
    }

    private func setupContext() {
        context.exceptionHandler = { [weak self] _, exception in
            self?.handleJavaScriptException(exception)
        }

        setupAPI()

        if let underscore = NSBundle.mainBundle().pathForResource("underscore-min", ofType: "js") {
            loadScript(underscore)
        }

        loadScript(primaryConfigPath)
    }

    private func setupAPI() {
        setupStarkObject()

        context.setObject(Application.self, forKeyedSubscript: "Application")
        context.setObject(Window.self, forKeyedSubscript: "Window")
        context.setObject(NSScreen.self, forKeyedSubscript: "Screen")
        context.setObject(HotKey.self, forKeyedSubscript: "HotKey")
    }

    private func setupStarkObject() {
        let stark = JSValue(newObjectInContext: context)
        context.setObject(stark.self, forKeyedSubscript: "Stark")

        let log: @convention(block) String -> () = {
            NSLog("%@", $0)
        }
        stark.setValue(unsafeBitCast(log, AnyObject.self), forProperty: "log")

        let reload: @convention(block) () -> () = {
            self.load()
        }
        stark.setValue(unsafeBitCast(reload, AnyObject.self), forProperty: "reload")

        let bind: @convention(block) (String, [String], JSValue) -> HotKey = { key, modifiers, handler in
            var hotkey = self.hotkeys[HotKey.hashForKey(key, modifiers: modifiers)]

            if hotkey == nil {
                hotkey = HotKey(key: key, modifiers: modifiers)
            }

            hotkey?.setHandler {
                handler.callWithArguments(nil)
            }

            self.hotkeys[hotkey!.hashValue] = hotkey
            return hotkey!
        }
        stark.setValue(unsafeBitCast(bind, AnyObject.self), forProperty: "bind")
    }

    private func loadScript(path: String) {
        if let script = try? String(contentsOfFile: path) {
            context.evaluateScript(script)
        } else {
            NSLog("Unable to load script: %@", path)
        }
    }

    private func handleJavaScriptException(exception: JSValue) {
        NSLog("JavaScript exception: %@", exception)
    }
}