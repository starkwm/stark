//
//  NSScreen+JSExport.swift
//  Stark
//
//  Created by Tom Bell on 28/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit
import JavaScriptCore

@objc
protocol NSScreenJSExport: JSExport {
    static func all() -> [NSScreen]
    static func focused() -> NSScreen?

    var identifier: String { get }
    var frameIncludingDockAndMenu: CGRect { get }
    var frameWithoutDockOrMenu: CGRect { get }
    var next: NSScreen? { get }
    var previous: NSScreen? { get }
}
