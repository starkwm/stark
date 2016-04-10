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
    private var observer: RunningAppsObserver

    private var hotkeys: [Int: KeyHandler]

    private static func resolvePrimaryConfigPath() -> String {
        for primaryConfigPath in primaryConfigPaths {
            let resolvedConfigPath = (primaryConfigPath as NSString).stringByResolvingSymlinksInPath

            if NSFileManager.defaultManager().fileExistsAtPath(resolvedConfigPath) {
                return resolvedConfigPath
            }
        }

        let path = primaryConfigPaths.first! as NSString
        return path.stringByResolvingSymlinksInPath
    }

    init() {
        primaryConfigPath = Config.resolvePrimaryConfigPath()
        context = JSContext(virtualMachine: JSVirtualMachine())
        observer = RunningAppsObserver()
        hotkeys = [Int: KeyHandler]()
    }

    public func load() {
        resetHotKeys()

        if !NSFileManager.defaultManager().fileExistsAtPath(primaryConfigPath) {
            createConfigFile(primaryConfigPath)
        }

        setupContext()
    }

    public func bindKey(key: String, modifiers: [String], callback: JSValue) -> KeyHandler {
        var hotkey = hotkeys[KeyHandler.hashForKey(key, modifiers: modifiers)]

        if hotkey == nil {
            hotkey = KeyHandler(key: key, modifiers: modifiers)
        }

        hotkey!.manageCallback(callback)

        hotkeys[hotkey!.hashValue] = hotkey
        return hotkey!
    }

    private func resetHotKeys() {
        hotkeys.forEach { $1.disable() }
        hotkeys.removeAll()
    }

    private func createConfigFile(path: String) {
        if let example = NSBundle.mainBundle().pathForResource("stark-example", ofType: "js") {
            if !NSFileManager.defaultManager().createFileAtPath(path, contents: NSData(contentsOfFile: example), attributes: nil) {
                let msg = String("Unable to create configuration file: %@", path)
                NSLog(msg)
                LogHelper.log(msg)
            }
            else {
                AlertHelper.showConfigDialog(path)
            }
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
        context.setObject(Stark.self(config: self), forKeyedSubscript: "Stark")
        context.setObject(Application.self, forKeyedSubscript: "App")
        context.setObject(Window.self, forKeyedSubscript: "Window")
        context.setObject(NSScreen.self, forKeyedSubscript: "Screen")
        context.setObject(KeyHandler.self, forKeyedSubscript: "KeyHandler")
    }

    private func loadScript(path: String) {
        if let script = try? String(contentsOfFile: path) {
            context.evaluateScript(script)
        } else {
            let msg = String(format: "Unable to load script: %@", path)
            NSLog(msg)
            LogHelper.log(msg)
        }
    }

    private func handleJavaScriptException(exception: JSValue) {
        let err = String(format: "JavaScript exception: %@", exception)
        NSLog(err)
        LogHelper.log(err)
    }
}