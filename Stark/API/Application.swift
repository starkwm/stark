import AppKit
import JavaScriptCore

@objc protocol ApplicationJSExport: JSExport {
    static func runningApps() -> [Application]
    static func frontmostApp() -> Application?

    func allWindows() -> [Window]
    func visibleWindows() -> [Window]

    func name() -> String
    func bundleId() -> String
    func processId() -> pid_t

    func activate() -> Bool
    func show() -> Bool
    func hide() -> Bool

    func isActive() -> Bool
    func isHidden() -> Bool
    func isTerminated() -> Bool
}

public class Application: NSObject, ApplicationJSExport {
    private var element: AXUIElementRef
    private var app: NSRunningApplication

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

    public func name() -> String {
        return app.localizedName ?? ""
    }

    public func bundleId() -> String {
        return app.bundleIdentifier ?? ""
    }

    public func processId() -> pid_t {
        return app.processIdentifier
    }

    public func activate() -> Bool {
        return app.activateWithOptions(.ActivateAllWindows)
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