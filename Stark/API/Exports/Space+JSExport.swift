//
//  Space+JSExport.swift
//  Stark
//
//  Created by Tom Bell on 28/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit
import JavaScriptCore

@objc
protocol SpaceJSExport: JSExport {
    static func active() -> Space
    static func all() -> [Space]

    func screens() -> [NSScreen]
}
