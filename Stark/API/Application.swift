import AppKit
import JavaScriptCore

@objc protocol ApplicationJSExport: JSExport {
    static func find(name: String) -> Application?

    static func all() -> [Application]
    static func focused() -> Application?

    var allWindows: [Window] { get }
    var visibleWindows: [Window] { get }

    var name: String { get }
    var bundleId: String { get }
    var processId: pid_t { get }

    func activate() -> Bool
    func focus() -> Bool

    func show() -> Bool
    func hide() -> Bool

    var isActive: Bool { get }
    var isHidden: Bool { get }
    var isTerminated: Bool { get }
}

public class Application: NSObject, ApplicationJSExport {
    private var element: AXUIElement
    private var app: NSRunningApplication

    public static func find(name: String) -> Application? {
        for app in NSWorkspace.sharedWorkspace().runningApplications {
            if app.localizedName == name {
                return Application(pid: app.processIdentifier)
            }
        }

        return nil
    }

    public static func all() -> [Application] {
        return NSWorkspace.sharedWorkspace().runningApplications.map {
            Application(pid: $0.processIdentifier)
        }
    }

    public static func focused() -> Application? {
        if let app = NSWorkspace.sharedWorkspace().frontmostApplication {
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

    public var allWindows: [Window] {
        get {
            var values: CFArray?
            let result = AXUIElementCopyAttributeValues(element, kAXWindowsAttribute, 0, 100, &values)

            if result != .Success {
                return []
            }

            let elements = values! as [AnyObject]

            // swiftlint:disable:next force_cast
            return elements.map { Window(element: $0 as! AXUIElement) }
        }
    }

    public var visibleWindows: [Window] {
        get {
            return allWindows.filter { !$0.app.isHidden && $0.isStandard && !$0.isMinimized }
        }
    }

    public var name: String {
        get { return app.localizedName ?? "" }
    }

    public var bundleId: String {
        get { return app.bundleIdentifier ?? "" }
    }

    public var processId: pid_t {
        get { return app.processIdentifier }
    }

    public func activate() -> Bool {
        return app.activateWithOptions(.ActivateAllWindows)
    }

    public func focus() -> Bool {
        return app.activateWithOptions(.ActivateIgnoringOtherApps)
    }

    public func show() -> Bool {
        return app.unhide()
    }

    public func hide() -> Bool {
        return app.hide()
    }

    public var isActive: Bool {
        get {
            return app.active
        }
    }

    public var isHidden: Bool {
        get {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(element, kAXHiddenAttribute, &value)

            if result != .Success {
                return false
            }

            if let number = value as? NSNumber {
                return number.boolValue
            }

            return false
        }
    }

    public var isTerminated: Bool {
        get {
            return app.terminated
        }
    }
}
