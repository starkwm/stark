import Alicia
import JavaScriptCore

/// The context for the JavaScript API for Stark.
class JavaScriptContext {
  var config: Config

  /// The context for executed the JavaScript configuration file.
  var context: JSContext?

  /// Initialise with the configuration file.
  init(config: Config) {
    self.config = config
  }

  /// Load the JavaScript library and configuration files into the JavaScript environment.
  func setup() {
    guard let libPath = Bundle.main.path(forResource: "library", ofType: "js") else {
      fatalError("Could not find library.js")
    }

    setupAPI()

    loadJSFile(path: libPath)

    Alicia.stop()
    Alicia.reset()

    if FileManager.default.fileExists(atPath: config.primaryPath) {
      loadJSFile(path: config.primaryPath)
    }

    Alicia.start()
  }
  
  /// Set up the public API for the configuration file environment.
  private func setupAPI() {
    context = JSContext(virtualMachine: JSVirtualMachine())

    guard let context else {
      fatalError("Could not setup JavaScript virtual machine")
    }

    if UserDefaults.standard.bool(forKey: logJavaScriptExceptionsKey) {
      context.exceptionHandler = { _, err in
        LogHelper.log(message: String(format: "Error: unhandled JavaScript exception (%@)", err!))
      }
    }

    context.setObject(
      Stark.self(context: self),
      forKeyedSubscript: "Stark" as (NSCopying & NSObjectProtocol)
    )

    context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as (NSCopying & NSObjectProtocol))

    context.setObject(Application.self, forKeyedSubscript: "Application" as (NSCopying & NSObjectProtocol))
    context.setObject(Window.self, forKeyedSubscript: "Window" as (NSCopying & NSObjectProtocol))
    context.setObject(Space.self, forKeyedSubscript: "Space" as (NSCopying & NSObjectProtocol))

    context.setObject(Keymap.self, forKeyedSubscript: "Keymap" as (NSCopying & NSObjectProtocol))
  }

  /// Evaluate the given JavaScript file in the JavaScript context.
  private func loadJSFile(path: String) {
    guard let scriptContents = try? String(contentsOfFile: path) else {
      fatalError(String(format: "Could not read script (%@)", path))
    }

    guard let context else {
      fatalError("Could not setup JavaScript virtual machine")
    }

    context.evaluateScript(scriptContents)
  }
}
