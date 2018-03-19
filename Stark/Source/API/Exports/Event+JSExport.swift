//
//  Event+JSExport.swift
//  Stark
//
//  Created by Tom Bell on 28/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import JavaScriptCore

@objc
protocol EventJSExport: JSExport {
    init(event: String, callback: JSValue)

    var name: String { get }

    func disable()
}
