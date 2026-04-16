import JavaScriptCore

enum JSCallbackInvoker {
  static func call(_ callback: JSValue?, withArguments arguments: [Any]) {
    guard let callback else { return }
    guard let context = callback.context else { return }

    let previousExceptionHandler = context.exceptionHandler
    context.exceptionHandler = { _, err in
      log("unhandled javascript exception - \(String(describing: err))", level: .error)
    }

    callback.call(withArguments: arguments)
    context.exceptionHandler = previousExceptionHandler
  }
}
