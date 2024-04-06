import Alicia
import JavaScriptCore

/// The context for the JavaScript API for Stark.
class Config {
  /// An array of primary locations of the configuration file.
  static let primaryPaths: [String] = [
    "~/.stark.js",
    "~/.config/stark/stark.js",
    "~/Library/Application Support/Stark/stark.js",
  ]

  /// Resolve the path of the configuration file to the first found location.
  static func resolvePrimaryPath() -> String {
    for configPath in primaryPaths {
      let resolvedConfigPath = (configPath as NSString).resolvingSymlinksInPath

      if FileManager.default.fileExists(atPath: resolvedConfigPath) {
        return resolvedConfigPath
      }
    }

    return (primaryPaths.first! as NSString).resolvingSymlinksInPath
  }

  var configPath: String

  /// The context for executed the JavaScript configuration file.
  var context: JSContext?

  /// Initialise with the configuration file path.
  init() {
    self.configPath = Self.resolvePrimaryPath()
  }

  /// Exevute the configuration files in the JavaScript execution environment.
  func execute() {
    guard let libPath = Bundle.main.path(forResource: "library", ofType: "js") else {
      fatalError("Could not find library.js")
    }

    setupAPI()

    loadFile(path: libPath)

    Alicia.stop()
    Alicia.reset()

    if FileManager.default.fileExists(atPath: configPath) {
      loadFile(path: configPath)
    }

    Alicia.start()
  }

  /// Set up the API for the configuration file JavaScript environment.
  private func setupAPI() {
    context = JSContext(virtualMachine: JSVirtualMachine())

    guard let context else {
      fatalError("Could not setup JavaScript virtual machine")
    }

    if UserDefaults.standard.bool(forKey: logJavaScriptExceptionsKey) {
      context.exceptionHandler = { _, err in
        LogHelper.log(message: "\(err!)")
      }
    }

    let print: @convention(block) (String) -> Void = { message in
      LogHelper.log(message: message)
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
  }

  /// Evaluate the given JavaScript file in the JavaScript context.
  private func loadFile(path: String) {
    guard let scriptContents = try? String(contentsOfFile: path) else {
      fatalError(String(format: "Could not read script (%@)", path))
    }

    guard let context else {
      fatalError("Could not setup JavaScript virtual machine")
    }

    context.evaluateScript(scriptContents)
  }
}
