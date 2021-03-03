import AppKit
import JavaScriptCore

// XXX: Undocumented private attribute for full screen mode
private let kAXFullscreenAttribute = "AXFullScreen"

private let starkVisibilityOptionsKey = "visible"

public class Window: NSObject, WindowJSExport {
    private static let systemWideElement = AXUIElementCreateSystemWide()

    public static func all(_ options: [String: AnyObject] = [:]) -> [Window] {
        App.all().flatMap { $0.windows(options) }
    }

    public static func focused() -> Window? {
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

    override public func isEqual(_ object: Any?) -> Bool {
        guard let window = object as? Window else {
            return false
        }

        return identifier == window.identifier
    }

    private var element: AXUIElement

    public var identifier: CGWindowID {
        var identifier: CGWindowID = 0
        _AXUIElementGetWindow(element, &identifier)
        return identifier
    }

    public var app: App {
        App(pid: pid())
    }

    public var screen: NSScreen {
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

    public var title: String {
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

    public var frame: CGRect {
        CGRect(origin: topLeft, size: size)
    }

    public var topLeft: CGPoint {
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

    public var size: CGSize {
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

    public var isMain: Bool {
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

    public var isStandard: Bool {
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

    public var isFullscreen: Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXFullscreenAttribute as CFString, &value)

        if result != .success {
            return false
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        return false
    }

    public var isMinimized: Bool {
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

    public func setFrame(_ frame: CGRect) {
        setTopLeft(frame.origin)
        setSize(frame.size)
    }

    public func setTopLeft(_ topLeft: CGPoint) {
        var val = topLeft
        let value = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    public func setSize(_ size: CGSize) {
        var val = size
        let value = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    public func maximize() {
        setFrame(screen.frameIncludingDockAndMenu)
    }

    public func minimize() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, true as CFTypeRef)
    }

    public func unminimize() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, false as CFTypeRef)
    }

    public func focus() {
        let result = AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)

        if result != .success {
            return
        }

        if let app = NSRunningApplication(processIdentifier: pid()) {
            app.activate(options: NSApplication.ActivationOptions.activateIgnoringOtherApps)
        }
    }

    public func spaces() -> [Space] {
        Space.spaces(for: self)
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
