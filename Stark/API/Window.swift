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
    fileprivate static let systemWideElement = AXUIElementCreateSystemWide()

    fileprivate var element: AXUIElement

    open static func all() -> [Window] {
        return Application.all().flatMap { $0.allWindows }
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
        get {
            return Application(pid: pid())
        }
    }

    open var screen: NSScreen {
        get {
            let windowFrame = frame
            var lastVolume: CGFloat = 0
            var lastScreen = NSScreen()

            for screen in NSScreen.screens()! {
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
    }

    open var title: String {
        get {
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
    }

    open var frame: CGRect {
        get {
            return CGRect(origin: topLeft, size: size)
        }
    }

    open var topLeft: CGPoint {
        get {
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
    }

    open var size: CGSize {
        get {
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
    }

    open func setFrame(_ frame: CGRect) {
        setSize(frame.size)
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
            app.activate(options: NSApplicationActivationOptions.activateIgnoringOtherApps)
        }
    }

    open var isMain: Bool {
        get {
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
    }

    open var isStandard: Bool {
        get {
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
    }

    open var isMinimized: Bool {
        get {
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
    }

    fileprivate func pid() -> pid_t {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)

        if result != .success {
            return 0
        }

        return pid
    }
}
