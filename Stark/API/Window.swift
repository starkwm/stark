import AppKit
import JavaScriptCore

@objc protocol WindowJSExport: JSExport {
    static func all() -> [Window]
    static func visible() -> [Window]
    static func focused() -> Window?

    var app: Application { get }

    var screen: NSScreen { get }

    var title: String { get }

    var frame: CGRect { get }
    var topLeft: CGPoint { get }
    var size: CGSize { get }

    func setFrame(frame: CGRect)
    func setTopLeft(topLeft: CGPoint)
    func setSize(size: CGSize)

    func maximize()
    func minimize()
    func unminimize()

    func focus()

    var isStandard: Bool { get }
    var isMain: Bool { get }
    var isMinimized: Bool { get }
}

public class Window: NSObject, WindowJSExport {
    private static let systemWideElement = AXUIElementCreateSystemWide()

    private var element: AXUIElement

    public static func all() -> [Window] {
        return Application.all().flatMap { $0.allWindows }
    }

    public static func visible() -> [Window] {
        return all().filter { !$0.app.isHidden && !$0.isMinimized && $0.isStandard }
    }

    public static func focused() -> Window? {
        var app: AnyObject?
        AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute, &app)

        if app == nil {
            return nil
        }

        var window: AnyObject?

        // swiftlint:disable:next force_cast
        let result = AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute, &window)

        if result != .Success {
            return nil
        }

        // swiftlint:disable:next force_cast
        return Window(element: window as! AXUIElement)
    }

    init(element: AXUIElement) {
        self.element = element
    }

    public var app: Application {
        get {
            return Application(pid: pid())
        }
    }

    public var screen: NSScreen {
        get {
            let windowFrame = frame
            var lastVolume: CGFloat = 0
            var lastScreen = NSScreen()

            for screen in NSScreen.screens()! {
                let screenFrame = screen.frameIncludingDockAndMenu
                let intersection = windowFrame.intersect(screenFrame)
                let volume = intersection.size.width * intersection.size.height

                if volume > lastVolume {
                    lastVolume = volume
                    lastScreen = screen
                }
            }

            return lastScreen
        }
    }

    public var title: String {
        get {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute, &value)

            if result != .Success {
                return ""
            }

            if let title = value as? String {
                return title
            }

            return ""
        }
    }

    public var frame: CGRect {
        get {
            return CGRect(origin: topLeft, size: size)
        }
    }

    public var topLeft: CGPoint {
        get {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute, &value)

            var topLeft = CGPoint.zero

            if result == .Success {
                // swiftlint:disable:next force_cast
                if !AXValueGetValue(value as! AXValueRef, AXValueType.CGPoint, &topLeft) {
                    topLeft = CGPoint.zero
                }
            }

            return topLeft
        }
    }

    public var size: CGSize {
        get {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute, &value)

            var size = CGSize.zero

            if result == .Success {
                // swiftlint:disable:next force_cast
                if !AXValueGetValue(value as! AXValueRef, AXValueType.CGSize, &size) {
                    size = CGSize.zero
                }
            }

            return size
        }
    }

    public func setFrame(frame: CGRect) {
        setSize(frame.size)
        setTopLeft(frame.origin)
        setSize(frame.size)
    }

    public func setTopLeft(topLeft: CGPoint) {
        var val = topLeft
        let value = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
        AXUIElementSetAttributeValue(element, kAXPositionAttribute, value)
    }

    public func setSize(size: CGSize) {
        var val = size
        let value = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
        AXUIElementSetAttributeValue(element, kAXSizeAttribute, value)
    }

    public func maximize() {
        setFrame(screen.frameIncludingDockAndMenu)
    }

    public func minimize() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute, true)
    }

    public func unminimize() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute, false)
    }

    public func focus() {
        let result = AXUIElementSetAttributeValue(element, kAXMainAttribute, kCFBooleanTrue)

        if result != .Success {
            return
        }

        if let app = NSRunningApplication(processIdentifier: pid()) {
            app.activateWithOptions(NSApplicationActivationOptions.ActivateIgnoringOtherApps)
        }
    }

    public var isMain: Bool {
        get {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(element, kAXMainAttribute, &value)

            if result != .Success {
                return false
            }

            if let number = value as? NSNumber {
                return number.boolValue
            }

            return false
        }
    }

    public var isStandard: Bool {
        get {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute, &value)

            if result != .Success {
                return false
            }

            if let subrole = value as? String {
                return subrole == kAXStandardWindowSubrole
            }

            return false
        }
    }

    public var isMinimized: Bool {
        get {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute, &value)

            if result != .Success {
                return false
            }

            if let number = value as? NSNumber {
                return number.boolValue
            }

            return false
        }
    }

    private func pid() -> pid_t {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)

        if result != .Success {
            return 0
        }

        return pid
    }
}
