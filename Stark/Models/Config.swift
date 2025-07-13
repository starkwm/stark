import AppKit
import JavaScriptCore

class Config {
  var context: JSContext?

  private let primaryPaths: [String] = [
    "~/.stark.js",
    "~/.config/stark/stark.js",
    "~/Library/Application Support/Stark/stark.js",
  ]

  func execute() {
    Keymap.reset()

    ShortcutManager.stop()
    ShortcutManager.reset()

    if !setupAPI() {
      return
    }

    let configPath = resolvePrimaryPath()

    if !FileManager.default.fileExists(atPath: configPath) {
      error("configuration file does not exist \(configPath)")
      return
    }

    if !loadFile(path: configPath) {
      return
    }

    ShortcutManager.start()
  }

  private func setupAPI() -> Bool {
    context = JSContext(virtualMachine: JSVirtualMachine())

    guard let context else {
      error("could not create javascript context")
      return false
    }

    context.exceptionHandler = { _, err in
      error("javascript exception - \(String(describing: err))")
    }

    let jsPrint: @convention(block) (String) -> Void = { message in
      debug(message)
    }

    let reload: @convention(block) () -> Void = {
      self.execute()
    }

    context.setObject(jsPrint, forKeyedSubscript: "print" as NSString)
    context.setObject(reload, forKeyedSubscript: "reload" as NSString)

    context.setObject(Keymap.self, forKeyedSubscript: "Keymap" as NSString)
    context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as NSString)
    context.setObject(Space.self, forKeyedSubscript: "Space" as NSString)
    context.setObject(Application.self, forKeyedSubscript: "Application" as NSString)
    context.setObject(Window.self, forKeyedSubscript: "Window" as NSString)

    return true
  }

  private func loadFile(path: String) -> Bool {
    guard let context else {
      error("javascript context is not defined")
      return false
    }

    guard let scriptContents = try? String(contentsOfFile: path, encoding: .utf8) else {
      error("could not read file \(path)")
      return false
    }

    context.evaluateScript(scriptContents)
    return true
  }

  private func resolvePrimaryPath() -> String {
    for configPath in primaryPaths {
      let resolvedConfigPath = (configPath as NSString).resolvingSymlinksInPath

      if FileManager.default.fileExists(atPath: resolvedConfigPath) {
        return resolvedConfigPath
      }
    }

    return (primaryPaths.first! as NSString).resolvingSymlinksInPath
  }
}
