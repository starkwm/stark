import JavaScriptCore

enum JSCallbackInvoker {
  static func addManagedReference(for object: AnyObject, callback: JSValue, owner: Any) {
    callback.context.virtualMachine.addManagedReference(object, withOwner: owner)
  }

  static func removeManagedReference(for object: AnyObject, callback: JSManagedValue?, owner: Any) {
    guard let callback = callback?.value else { return }

    callback.context.virtualMachine.removeManagedReference(object, withOwner: owner)
  }

  static func call(_ callback: JSManagedValue?, withArguments arguments: [Any]) {
    guard let callback = callback?.value else { return }
    guard let context = callback.context else { return }

    let previousExceptionHandler = context.exceptionHandler
    context.exceptionHandler = { _, err in
      log("unhandled javascript exception - \(String(describing: err))", level: .error)
    }

    callback.call(withArguments: arguments)
    context.exceptionHandler = previousExceptionHandler
  }
}
