import AppKit
import JavaScriptCore

private let starkVisibilityOptionsKey = "visible"

@objc
protocol ApplicationJSExport: JSExport {
    static func find(_ name: String) -> Application?
    static func launch(_ name: String)

    static func all() -> [Application]
    static func focused() -> Application?

    var name: String { get }
    var bundleId: String { get }
    var processId: pid_t { get }

    var isActive: Bool { get }
    var isHidden: Bool { get }
    var isTerminated: Bool { get }

    func windows() -> [Window]
    func windows(_ options: [String: AnyObject]) -> [Window]

    func activate() -> Bool
    func focus() -> Bool

    func show() -> Bool
    func hide() -> Bool

    func terminate() -> Bool
}

public class Application: NSObject, ApplicationJSExport {
    /// Static Functions

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

    /// Initializers

    init(pid: pid_t) {
        self.element = AXUIElementCreateApplication(pid)
        self.app = NSRunningApplication(processIdentifier: pid)!
    }

    init(app: NSRunningApplication) {
        self.element = AXUIElementCreateApplication(app.processIdentifier)
        self.app = app
    }

    /// Instance Variables

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

    /// Instance Functions

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
