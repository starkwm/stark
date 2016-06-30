import AppKit
import JavaScriptCore

@objc protocol ApplicationJSExport: JSExport {
    static func find(name: String) -> Application?

    static func runningApps() -> [Application]
    static func frontmostApp() -> Application?

    func allWindows() -> [Window]
    func visibleWindows() -> [Window]

    var name: String { get }
    var bundleId: String { get }
    var processId: pid_t { get }

    func activate() -> Bool
    func focus() -> Bool
    func show() -> Bool
    func hide() -> Bool

    func isActive() -> Bool
    func isHidden() -> Bool
    func isTerminated() -> Bool
}

public class Application: NSObject, ApplicationJSExport {
    private var element: AXUIElementRef
    private var app: NSRunningApplication

    public static func find(name: String) -> Application? {
        for app in NSWorkspace.sharedWorkspace().runningApplications {
            if app.localizedName == name {
                return Application(pid: app.processIdentifier)
            }
        }

        return nil
    }

    public static func runningApps() -> [Application] {
        return NSWorkspace.sharedWorkspace().runningApplications.map {
            Application(pid: $0.processIdentifier)
        }
    }

    public static func frontmostApp() -> Application? {
        if let app = NSWorkspace.sharedWorkspace().frontmostApplication {
            return Application(pid: app.processIdentifier)
        }

        return nil
    }

    init(pid: pid_t) {
        self.element = AXUIElementCreateApplication(pid).takeRetainedValue()
        self.app = NSRunningApplication(processIdentifier: pid)!
    }

    init(app: NSRunningApplication) {
        self.element = AXUIElementCreateApplication(app.processIdentifier).takeRetainedValue()
        self.app = app
    }

    public func allWindows() -> [Window] {
        var values: CFArray?
        let result = AXUIElementCopyAttributeValues(element, kAXWindowsAttribute, 0, 100, &values)

        if result != .Success {
            return []
        }

        return (values! as [AnyObject]).map { Window(element: $0 as! AXUIElementRef) }
    }

    public func visibleWindows() -> [Window] {
        return allWindows().filter { !$0.app().isHidden() && $0.isStandard() && !$0.isMinimized() }
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

    public func isActive() -> Bool {
        return app.active
    }

    public func isHidden() -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXHiddenAttribute, &value)

        if result != .Success {
            return false
        }

        return (value as! NSNumber).boolValue
    }

    public func isTerminated() -> Bool {
        return app.terminated
    }
}