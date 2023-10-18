import AppKit

// XXX: Undocumented private attribute for enhanced user interface
private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

private let starkVisibilityOptionsKey = "visible"

public class Application: NSObject, ApplicationJSExport {
    public static func find(_ name: String) -> Application? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }) {
            return Application(pid: app.processIdentifier)
        }

        return nil
    }

    public static func all() -> [Application] {
        NSWorkspace.shared.runningApplications.map { Application(pid: $0.processIdentifier) }
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

    public var name: String { app.localizedName ?? "" }

    public var bundleId: String { app.bundleIdentifier ?? "" }

    public var processId: pid_t { app.processIdentifier }

    public var isActive: Bool { app.isActive }

    public var isHidden: Bool {
        var value: AnyObject?

        if AXUIElementCopyAttributeValue(element, kAXHiddenAttribute as CFString, &value) == .success {
            if let number = value as? NSNumber {
                return number.boolValue
            }
        }

        return false
    }

    public var isTerminated: Bool {
        app.isTerminated
    }

    public func windows() -> [Window] {
        var values: CFArray?

        if AXUIElementCopyAttributeValues(element, kAXWindowsAttribute as CFString, 0, 100, &values) != .success {
            return []
        }

        return (values as? [AXUIElement] ?? []).map { Window(element: $0) }
    }

    public func windows(_ options: [String: AnyObject] = [:]) -> [Window] {
        let visible = options[starkVisibilityOptionsKey] as? Bool ?? false

        if visible {
            return windows().filter { !$0.app.isHidden && $0.isStandard && !$0.isMinimized }
        }

        return windows()
    }

    public func activate() -> Bool {
        app.activate(options: .activateAllWindows)
    }

    public func focus() -> Bool {
        app.activate(options: .activateIgnoringOtherApps)
    }

    public func show() -> Bool {
        app.unhide()
    }

    public func hide() -> Bool {
        app.hide()
    }

    public func terminate() -> Bool {
        app.terminate()
    }

    public func isEnhancedUserInterfaceEnabled() -> Bool? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXEnhancedUserInterface as CFString, &value)

        if result == .success, CFGetTypeID(value) == CFBooleanGetTypeID() {
            // swiftlint:disable:next force_cast
            return CFBooleanGetValue((value as! CFBoolean))
        }

        return nil
    }

    public func enableEnhancedUserInterface() {
        AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanTrue)
    }

    public func disableEnhancedUserInterface() {
        AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanFalse)
    }
}
