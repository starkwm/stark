//
//  Handler.swift
//  Stark
//
//  Created by Tom Bell on 22/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import Foundation
import JavaScriptCore

public class Handler: NSObject {
    /// Instance Variables

    internal var callback: JSManagedValue?

    /// Instance Functions

    func manageCallback(_ callback: JSValue) {
        self.callback = JSManagedValue(value: callback, andOwner: self)
    }

    func call(withArguments arguments: [AnyObject]!) {
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
        call(withArguments: [])
    }
}
