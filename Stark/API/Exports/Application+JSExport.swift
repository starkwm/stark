//
//  Application+JSExport.swift
//  Stark
//
//  Created by Tom Bell on 28/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import JavaScriptCore

@objc
protocol ApplicationJSExport: JSExport {
    static func find(_ name: String) -> Application?
    static func launch(_ name: String)
    static func all() -> [Application]
    static func focused() -> Application?

    var name: String { get }
    var bundleId: String { get }
    var processId: pid_t { get }
    var isActive: Bool { get }
    var isHidden: Bool { get }
    var isTerminated: Bool { get }

    func windows() -> [Window]
    func windows(_ options: [String: AnyObject]) -> [Window]
    func activate() -> Bool
    func focus() -> Bool
    func show() -> Bool
    func hide() -> Bool
    func terminate() -> Bool
}
