//
//  NSScreen+JSExport.swift
//  Stark
//
//  Created by Tom Bell on 22/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit

private let NSScreenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

extension NSScreen: NSScreenJSExport {
    public static func all() -> [NSScreen] {
        return screens
    }

    public static func focused() -> NSScreen? {
        return main
    }

    public static func screen(for identifier: String) -> NSScreen? {
        return screens.first(where: { $0.identifier == identifier })
    }

    public var identifier: String {
        guard let number = deviceDescription[NSScreenNumberKey] as? NSNumber else {
            return ""
        }

        let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value).takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }

    public var frameIncludingDockAndMenu: CGRect {
        let primaryScreen = NSScreen.screens.first
        var frame = self.frame
        frame.origin.y = primaryScreen!.frame.height - frame.height - frame.origin.y
        return frame
    }

    public var frameWithoutDockOrMenu: CGRect {
        let primaryScreen = NSScreen.screens.first
        var frame = visibleFrame
        frame.origin.y = primaryScreen!.frame.height - frame.height - frame.origin.y
        return frame
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

    public func spaces() -> [Space] {
        return Space.all().filter { $0.screens().contains(self) }
    }
}
