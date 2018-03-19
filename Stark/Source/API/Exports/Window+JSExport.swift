//
//  Window+JSExport.swift
//  Stark
//
//  Created by Tom Bell on 28/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit
import JavaScriptCore

@objc
protocol WindowJSExport: JSExport {
    static func all() -> [Window]
    static func all(_ options: [String: AnyObject]) -> [Window]
    static func focused() -> Window?

    var app: Application { get }
    var screen: NSScreen { get }

    var title: String { get }

    var frame: CGRect { get }
    var topLeft: CGPoint { get }
    var size: CGSize { get }

    var isStandard: Bool { get }
    var isMain: Bool { get }
    var isFullscreen: Bool { get }
    var isMinimized: Bool { get }

    func setFrame(_ frame: CGRect)
    func setTopLeft(_ topLeft: CGPoint)
    func setSize(_ size: CGSize)

    func maximize()
    func minimize()
    func unminimize()

    func focus()

    func spaces() -> [Space]
}
