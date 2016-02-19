import Foundation
import JavaScriptCore

public class Handler: NSObject {
    var callback: JSManagedValue?

    func manageCallback(callback: JSValue) {
        self.callback = JSManagedValue(value: callback, andOwner: self)
    }

    func callWithArguments(arguments: [AnyObject]!) {
        if let callback = self.callback?.value {
            let scope = JSContext(virtualMachine: callback.context.virtualMachine)

            scope.exceptionHandler = { _, exception in
                NSLog("JavaScript Exception: %@", exception)
            }

            let function = JSValue(object: callback, inContext: scope)

            function.callWithArguments(arguments)
        }
    }

    func call() {
        callWithArguments([])
    }
}