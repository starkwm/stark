import JavaScriptCore

struct ConfigScriptExecutor {
  var executeScript: (ConfigSession, JSContext, String) throws -> Void

  static let live = ConfigScriptExecutor(
    executeScript: { _, context, script in
      context.evaluateScript(script)

      if let exception = context.exception {
        throw JSExceptionError.exception("JS exception: \(exception)")
      }
    }
  )
}
