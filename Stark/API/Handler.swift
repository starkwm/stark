import Foundation
import JavaScriptCore

open class Handler: NSObject {
    var callback: JSManagedValue?

    func manageCallback(_ callback: JSValue) {
        self.callback = JSManagedValue(value: callback, andOwner: self)
    }

    func callWithArguments(_ arguments: [AnyObject]!) {
        if let callback = callback?.value {
            let scope = JSContext(virtualMachine: callback.context.virtualMachine)

            scope?.exceptionHandler = { _, exception in
                LogHelper.log(message: String(format: "JavaScript exception: %@", exception!))
            }

            let function = JSValue(object: callback, in: scope)
            _ = function?.call(withArguments: arguments)
        }
    }

    func call() {
        callWithArguments([])
    }
}
