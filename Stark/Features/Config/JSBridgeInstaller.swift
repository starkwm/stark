import AppKit
import JavaScriptCore

struct JSBridgeInstaller {
  var install: (JSContext) -> Void

  static let live = JSBridgeInstaller(
    install: { context in
      context.exceptionHandler = { _, err in
        log("javascript exception - \(String(describing: err))", level: .error)
      }

      let print: @convention(block) (String) -> Void = { message in
        log(message, level: .info)
      }

      context.setObject(print, forKeyedSubscript: "print" as NSString)
      context.setObject(Keymap.self, forKeyedSubscript: "Keymap" as NSString)
      context.setObject(Event.self, forKeyedSubscript: "Event" as NSString)
      context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as NSString)
      context.setObject(Space.self, forKeyedSubscript: "Space" as NSString)
      context.setObject(Application.self, forKeyedSubscript: "Application" as NSString)
      context.setObject(Window.self, forKeyedSubscript: "Window" as NSString)
    }
  )
}
