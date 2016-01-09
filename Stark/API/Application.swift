import AppKit
import JavaScriptCore

@objc protocol ApplicationJSExport: JSExport {
    static func runningApps() -> [Application]
    static func frontmostApp() -> Application?

    func title() -> String
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

    public func title() -> String {
        if let title = NSRunningApplication(processIdentifier: pid)?.localizedName {
            return title
        }

        return ""
    }
}
