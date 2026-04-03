import JavaScriptCore

struct ConfigScriptExecutor {
  var executeScript: (JSContext, String) -> Result<Void, Error>

  static let live = ConfigScriptExecutor(
    executeScript: { context, script in
      context.evaluateScript(script)

      if let exception = context.exception {
        return .failure(JSExceptionError.exception("JS exception: \(exception)"))
      }

      return .success(())
    }
  )
}
