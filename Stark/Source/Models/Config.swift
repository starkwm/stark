import Alicia
import JavaScriptCore
import OSLog

class Config {
  var context: JSContext?

  private let primaryPaths: [String] = [
    "~/.stark.js",
    "~/.config/stark/stark.js",
    "~/Library/Application Support/Stark/stark.js",
  ]

  func execute() {
    guard let libPath = Bundle.main.path(forResource: "library", ofType: "js") else {
      Logger.config.error("could not find library.js")
      return
    }

    if !setupAPI() {
      return
    }

    if !loadFile(path: libPath) {
      return
    }

    Alicia.reset()

    let configPath = resolvePrimaryPath()

    if !FileManager.default.fileExists(atPath: configPath) {
      Logger.config.error("configuration file does not exist \(configPath)")
      return
    }

    if !loadFile(path: configPath) {
      return
    }
  }

  private func setupAPI() -> Bool {
    context = JSContext(virtualMachine: JSVirtualMachine())

    guard let context else {
      Logger.config.error("could not create javascript context")
      return false
    }

    context.exceptionHandler = { _, err in
      Logger.javascript.error("\(err)")
    }

    let print: @convention(block) (String) -> Void = { message in
      Logger.javascript.info("\(message)")
    }

    let reload: @convention(block) () -> Void = {
      self.execute()
    }

    context.setObject(print, forKeyedSubscript: "print" as NSString)
    context.setObject(reload, forKeyedSubscript: "reload" as NSString)

    context.setObject(Keymap.self, forKeyedSubscript: "Keymap" as NSString)
    context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as NSString)
    context.setObject(Space.self, forKeyedSubscript: "Space" as NSString)
    context.setObject(Application.self, forKeyedSubscript: "Application" as NSString)
    context.setObject(Window.self, forKeyedSubscript: "Window" as NSString)

    return true
  }

  private func loadFile(path: String) -> Bool {
    guard let scriptContents = try? String(contentsOfFile: path) else {
      Logger.config.error("could not read file \(path)")
      return false
    }

    guard let context else {
      Logger.config.error("javascript context is not defined")
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
