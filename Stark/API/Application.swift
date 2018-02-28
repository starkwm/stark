//
//  Application.swift
//  Stark
//
//  Created by Tom Bell on 22/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit

private let starkVisibilityOptionsKey = "visible"

public class Application: NSObject, ApplicationJSExport {
    public static func find(_ name: String) -> Application? {
        let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name })

        guard app != nil else {
            return nil
        }

        return Application(pid: app!.processIdentifier)
    }

    public static func launch(_ name: String) {
        NSWorkspace.shared.launchApplication(name)
    }

    public static func all() -> [Application] {
        return NSWorkspace.shared.runningApplications.map { Application(pid: $0.processIdentifier) }
    }

    public static func focused() -> Application? {
        if let app = NSWorkspace.shared.frontmostApplication {
            return Application(pid: app.processIdentifier)
        }

        return nil
    }

    init(pid: pid_t) {
        element = AXUIElementCreateApplication(pid)
        app = NSRunningApplication(processIdentifier: pid)!
    }

    init(app: NSRunningApplication) {
        element = AXUIElementCreateApplication(app.processIdentifier)
        self.app = app
    }

    private var element: AXUIElement

    private var app: NSRunningApplication

    public var name: String { return app.localizedName ?? "" }

    public var bundleId: String { return app.bundleIdentifier ?? "" }

    public var processId: pid_t { return app.processIdentifier }

    public var isActive: Bool { return app.isActive }

    public var isHidden: Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXHiddenAttribute as CFString, &value)

        if result != .success {
            return false
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        return false
    }

    public var isTerminated: Bool {
        return app.isTerminated
    }

    public func windows() -> [Window] {
        var values: CFArray?
        let result = AXUIElementCopyAttributeValues(element, kAXWindowsAttribute as CFString, 0, 100, &values)

        if result != .success {
            return []
        }

        let elements = values! as [AnyObject]

        // swiftlint:disable:next force_cast
        return elements.map { Window(element: $0 as! AXUIElement) }
    }

    public func windows(_ options: [String: AnyObject]) -> [Window] {
        let visible = options[starkVisibilityOptionsKey] as? Bool ?? false

        if visible {
            return windows().filter { !$0.app.isHidden && $0.isStandard && !$0.isMinimized }
        }

        return windows()
    }

    public func activate() -> Bool {
        return app.activate(options: .activateAllWindows)
    }

    public func focus() -> Bool {
        return app.activate(options: .activateIgnoringOtherApps)
    }

    public func show() -> Bool {
        return app.unhide()
    }

    public func hide() -> Bool {
        return app.hide()
    }

    public func terminate() -> Bool {
        return app.terminate()
    }
}
