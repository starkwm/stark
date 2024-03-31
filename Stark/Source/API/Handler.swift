import Foundation
import JavaScriptCore

public class Handler: NSObject {
  var callback: JSManagedValue?

  func manageCallback(_ callback: JSValue?) {
    guard callback != nil else { return }
    self.callback = JSManagedValue(value: callback, andOwner: self)
  }

  func call() {
    if let callback = callback?.value {
      let scope = JSContext(virtualMachine: callback.context.virtualMachine)

      if UserDefaults.standard.bool(forKey: logJavaScriptExceptionsKey) {
        scope?.exceptionHandler = { _, exception in
          LogHelper.log(message: String(format: "Error: JavaScript exception (%@)", exception!))
        }
      }

      let function = JSValue(object: callback, in: scope)
      _ = function?.call(withArguments: [])
    }
  }
}
