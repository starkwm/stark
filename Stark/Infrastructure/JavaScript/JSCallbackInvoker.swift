import JavaScriptCore

enum JSCallbackInvoker {
  /// Retains a JS callback through the owning virtual machine for as long as Stark needs it.
  static func addManagedReference(for object: AnyObject, callback: JSValue, owner: Any) {
    callback.context.virtualMachine.addManagedReference(object, withOwner: owner)
  }

  /// Releases a previously retained JS callback from the owning virtual machine.
  static func removeManagedReference(for object: AnyObject, callback: JSManagedValue?, owner: Any) {
    guard let callback = callback?.value else { return }

    callback.context.virtualMachine.removeManagedReference(object, withOwner: owner)
  }

  /// Invokes a managed callback inside a fresh JS context that shares the same virtual machine.
  static func call(_ callback: JSManagedValue?, withArguments arguments: [Any]) {
    guard let callback = callback?.value else { return }

    guard let context = JSContext(virtualMachine: callback.context.virtualMachine) else { return }

    context.exceptionHandler = { _, err in
      log("unhandled javascript exception - \(String(describing: err))", level: .error)
    }

    let function = JSValue(object: callback, in: context)
    function?.call(withArguments: arguments)
  }
}
