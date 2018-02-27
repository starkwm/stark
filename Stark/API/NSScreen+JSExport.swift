//
//  NSScreen+JSExport.swift
//  Stark
//
//  Created by Tom Bell on 22/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit
import JavaScriptCore

private let NSScreenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

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

extension NSScreen: NSScreenJSExport {
    /// Static Functions

    public static func all() -> [NSScreen] {
        return screens
    }

    public static func focused() -> NSScreen? {
        return main
    }

    public static func screen(for identifier: String) -> NSScreen? {
        return screens.first(where: { $0.identifier == identifier })
    }

    /// Instance Variables

    public var identifier: String {
        guard let number = deviceDescription[NSScreenNumberKey] as? NSNumber else {
            return ""
        }

        let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value).takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }

    public var frameIncludingDockAndMenu: CGRect {
        let primaryScreen = NSScreen.screens.first
        var f = frame
        f.origin.y = primaryScreen!.frame.height - f.height - f.origin.y
        return f
    }

    public var frameWithoutDockOrMenu: CGRect {
        let primaryScreen = NSScreen.screens.first
        var f = visibleFrame
        f.origin.y = primaryScreen!.frame.height - f.height - f.origin.y
        return f
    }

    public var next: NSScreen? {
        let screens = NSScreen.screens

        if var index = screens.index(of: self) {
            index += 1

            if index == screens.count {
                index = 0
            }

            return screens[index]
        }

        return nil
    }

    public var previous: NSScreen? {
        let screens = NSScreen.screens

        if var index = screens.index(of: self) {
            index -= 1

            if index == -1 {
                index = screens.count - 1
            }

            return screens[index]
        }

        return nil
    }

    public func currentSpace() -> Space? {
        return Space.currentSpace(for: self)
    }

    public func spaces() -> [Space]? {
        return Space.all().filter { $0.screens().contains(self) }
    }
}
