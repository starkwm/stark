import AppKit
import JavaScriptCore

@objc protocol ApplicationJSExport: JSExport {
    static func runningApps() -> [Application]
    static func frontmostApp() -> Application?

    func allWindows() -> [Window]
    func visibleWindows() -> [Window]

    func title() -> String

    func show() -> Bool
    func hide() -> Bool

    func isHidden() -> Bool
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
        let result = AXUIElementCopyAttributeValues(element, kAXWindowAttribute, 0, 100, &values)

        if result != .Success {
            return []
        }

        return (values! as [AnyObject]).map { Window(element: $0 as! AXUIElementRef) }
    }

    public func visibleWindows() -> [Window] {
        return allWindows().filter { !$0.app().isHidden() && $0.isStandard() && !$0.isMinimized() }
    }

    public func title() -> String {
        if let title = NSRunningApplication(processIdentifier: pid)?.localizedName {
            return title
        }

        return ""
    }

    public func show() -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXHiddenAttribute, false)
        return result == .Success
    }

    public func hide() -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXHiddenAttribute, true)
        return result == .Success
    }

    public func isHidden() -> Bool {
        return false
    }
}
