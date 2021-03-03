import AppKit

private let starkVisibilityOptionsKey = "visible"

public class App: NSObject, ApplicationJSExport {
    public static func find(_ name: String) -> App? {
        let app = NSWorkspace.shared.runningApplications.first { $0.localizedName == name }

        guard app != nil else {
            return nil
        }

        return App(pid: app!.processIdentifier)
    }

    public static func all() -> [App] {
        NSWorkspace.shared.runningApplications.map { App(pid: $0.processIdentifier) }
    }

    public static func focused() -> App? {
        if let app = NSWorkspace.shared.frontmostApplication {
            return App(pid: app.processIdentifier)
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
        app.isTerminated
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
}
