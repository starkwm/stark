import AppKit
import JavaScriptCore

struct JSBridgeInstaller {
  static let live = JSBridgeInstaller(
    install: { context, session in
      context.exceptionHandler = { _, err in
        log("unhandled javascript exception - \(String(describing: err))", level: .error)
      }

      let print: @convention(block) (String) -> Void = { message in
        log(message, level: .info)
      }

      context.setObject(print, forKeyedSubscript: "print" as NSString)
      context.setObject(session.keymapBridge, forKeyedSubscript: "Keymap" as NSString)
      context.setObject(session.eventBridge, forKeyedSubscript: "Event" as NSString)
      context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as NSString)
      context.setObject(Space.self, forKeyedSubscript: "Space" as NSString)
      context.setObject(Application.self, forKeyedSubscript: "Application" as NSString)
      context.setObject(Window.self, forKeyedSubscript: "Window" as NSString)
    }
  )

  var install: (JSContext, ConfigSession) -> Void
}
