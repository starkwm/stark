import AppKit
import JavaScriptCore

@objc protocol ApplicationJSExport: JSExport {
    static func runningApps() -> [Application]
    static func frontmostApp() -> Application?
}

public class Application: NSObject {
    private var pid: pid_t
    private var element: AXUIElementRef

    init(pid: pid_t) {
        self.pid = pid
        self.element = AXUIElementCreateApplication(self.pid).takeRetainedValue()
    }
}
