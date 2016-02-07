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

    func show() -> Bool
    func hide() -> Bool

    func isActive() -> Bool
    func isHidden() -> Bool
    func isTerminated() -> Bool
}

public class Application: NSObject, ApplicationJSExport {
    private var pid: pid_t
    private var element: AXUIElementRef

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
        self.pid = pid
        self.element = AXUIElementCreateApplication(self.pid).takeRetainedValue()
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
        return NSRunningApplication(processIdentifier: pid)?.localizedName ?? ""
    }

    public func bundleId() -> String {
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
    }

    public func processId() -> pid_t {
        return pid
    }

    public func show() -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXHiddenAttribute, false)
        return result == .Success
    }

    public func hide() -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXHiddenAttribute, true)
        return result == .Success
    }

    public func isActive() -> Bool {
        return NSRunningApplication(processIdentifier: pid)?.active ?? false
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
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.terminated
        }

        return true
    }
}