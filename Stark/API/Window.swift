import AppKit
import JavaScriptCore

private let starkVisibilityOptionsKey = "visible"

@objc
protocol WindowJSExport: JSExport {
    static func all() -> [Window]
    static func all(_ options: [String: AnyObject]) -> [Window]

    static func focused() -> Window?

    var app: Application { get }

    var screen: NSScreen { get }

    var title: String { get }

    var frame: CGRect { get }
    var topLeft: CGPoint { get }
    var size: CGSize { get }

    func setFrame(_ frame: CGRect)
    func setTopLeft(_ topLeft: CGPoint)
    func setSize(_ size: CGSize)

    func maximize()
    func minimize()
    func unminimize()

    func focus()

    var isStandard: Bool { get }
    var isMain: Bool { get }
    var isMinimized: Bool { get }
}

open class Window: NSObject, WindowJSExport {
    private static let systemWideElement = AXUIElementCreateSystemWide()

    private var element: AXUIElement

    open static func all() -> [Window] {
        return Application.all().flatMap { $0.windows() }
    }

    static func all(_ options: [String: AnyObject]) -> [Window] {
        let visible = options[starkVisibilityOptionsKey] as? Bool ?? false

        if visible {
            return all().filter { !$0.app.isHidden && $0.isStandard && !$0.isMinimized }
        }

        return all()
    }

    open static func visible() -> [Window] {
        return all().filter { !$0.app.isHidden && !$0.isMinimized && $0.isStandard }
    }

    open static func focused() -> Window? {
        var app: AnyObject?
        AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &app)

        if app == nil {
            return nil
        }

        var window: AnyObject?

        // swiftlint:disable:next force_cast
        let result = AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &window)

        if result != .success {
            return nil
        }

        // swiftlint:disable:next force_cast
        return Window(element: window as! AXUIElement)
    }

    init(element: AXUIElement) {
        self.element = element
    }

    open var app: Application {
        return Application(pid: pid())
    }

    open var screen: NSScreen {
        let windowFrame = frame
        var lastVolume: CGFloat = 0
        var lastScreen = NSScreen()

        for screen in NSScreen.screens {
            let screenFrame = screen.frameIncludingDockAndMenu
            let intersection = windowFrame.intersection(screenFrame)
            let volume = intersection.size.width * intersection.size.height

            if volume > lastVolume {
                lastVolume = volume
                lastScreen = screen
            }
        }

        return lastScreen
    }

    open var title: String {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)

        if result != .success {
            return ""
        }

        if let title = value as? String {
            return title
        }

        return ""
    }

    open var frame: CGRect {
        return CGRect(origin: topLeft, size: size)
    }

    open var topLeft: CGPoint {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)

        var topLeft = CGPoint.zero

        if result == .success {
            // swiftlint:disable:next force_cast
            if !AXValueGetValue(value as! AXValue, AXValueType.cgPoint, &topLeft) {
                topLeft = CGPoint.zero
            }
        }

        return topLeft
    }

    open var size: CGSize {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)

        var size = CGSize.zero

        if result == .success {
            // swiftlint:disable:next force_cast
            if !AXValueGetValue(value as! AXValue, AXValueType.cgSize, &size) {
                size = CGSize.zero
            }
        }

        return size
    }

    open func setFrame(_ frame: CGRect) {
        setTopLeft(frame.origin)
        setSize(frame.size)
    }

    open func setTopLeft(_ topLeft: CGPoint) {
        var val = topLeft
        let value = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    open func setSize(_ size: CGSize) {
        var val = size
        let value = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    open func maximize() {
        setFrame(screen.frameIncludingDockAndMenu)
    }

    open func minimize() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, true as CFTypeRef)
    }

    open func unminimize() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, false as CFTypeRef)
    }

    open func focus() {
        let result = AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)

        if result != .success {
            return
        }

        if let app = NSRunningApplication(processIdentifier: pid()) {
            app.activate(options: NSApplication.ActivationOptions.activateIgnoringOtherApps)
        }
    }

    open var isMain: Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXMainAttribute as CFString, &value)

        if result != .success {
            return false
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        return false
    }

    open var isStandard: Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value)

        if result != .success {
            return false
        }

        if let subrole = value as? String {
            return subrole == kAXStandardWindowSubrole
        }

        return false
    }

    open var isMinimized: Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value)

        if result != .success {
            return false
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        return false
    }

    private func pid() -> pid_t {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)

        if result != .success {
            return 0
        }

        return pid
    }
}
