//
//  Bind+JSExport.swift
//  Stark
//
//  Created by Tom Bell on 28/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import JavaScriptCore

@objc
protocol BindJSExport: JSExport {
    init(key: String, modifiers: [String], callback: JSValue)

    var key: String { get }
    var modifiers: [String] { get }

    var isEnabled: Bool { get }

    func enable() -> Bool
    func disable() -> Bool
}
