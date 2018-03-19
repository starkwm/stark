//
//  AlertHelper.swift
//  Stark
//
//  Created by Tom Bell on 22/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit

class AlertHelper {
    static func show(message: String, description: String? = nil, error: NSError? = nil) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = description ?? (error?.localizedDescription ?? "")
        alert.alertStyle = .critical

        alert.runModal()
    }
}
