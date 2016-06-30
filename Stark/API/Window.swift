import AppKit
import JavaScriptCore

@objc protocol WindowJSExport: JSExport {
    static func allWindows() -> [Window]
    static func visibleWindows() -> [Window]
    static func focusedWindow() -> Window?

    func app() -> Application

    func screen() -> NSScreen

    // TODO: make property
    func title() -> String

    // TODO: make property
    func frame() -> CGRect
    // TODO: make property
    func topLeft() -> CGPoint
    // TODO: make property
    func size() -> CGSize

    func setFrame(frame: CGRect)
    func setTopLeft(topLeft: CGPoint)
    func setSize(size: CGSize)

    func maximize()
    func minimize()
    func unminimize()

    func focus()

    func isStandard() -> Bool
    func isMain() -> Bool
    func isMinimized() -> Bool
}

public class Window: NSObject, WindowJSExport {
    private static let systemWideElement = AXUIElementCreateSystemWide().takeRetainedValue()

    private var element: AXUIElementRef

    public static func allWindows() -> [Window] {
        return Application.runningApps().flatMap { $0.allWindows() }
    }

    public static func visibleWindows() -> [Window] {
        return allWindows().filter { !$0.app().isHidden() && !$0.isMinimized() && $0.isStandard() }
    }

    public static func focusedWindow() -> Window? {
        var app: AnyObject?
        AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute, &app)

        if app == nil {
            return nil
        }

        var window: AnyObject?
        let result = AXUIElementCopyAttributeValue(app as! AXUIElementRef, kAXFocusedWindowAttribute, &window)

        if result != .Success {
            return nil
        }

        return Window(element: window as! AXUIElementRef)
    }

    init(element: AXUIElementRef) {
        self.element = element
    }

    public func app() -> Application {
        return Application(pid: pid())
    }

    public func screen() -> NSScreen {
        let windowFrame = frame()
        var lastVolume: CGFloat = 0
        var lastScreen = NSScreen()

        for screen in NSScreen.screens()! {
            let screenFrame = screen.frameIncludingDockAndMenu
            let intersection = CGRectIntersection(windowFrame, screenFrame)
            let volume = intersection.size.width * intersection.size.height

            if (volume > lastVolume) {
                lastVolume = volume
                lastScreen = screen
            }
        }

        return lastScreen
    }

    public func title() -> String {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute, &value)

        if result != .Success {
            return ""
        }

        return value as! String
    }

    public func frame() -> CGRect {
        return CGRect(origin: topLeft(), size: size())
    }

    public func topLeft() -> CGPoint {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute, &value)

        var topLeft = CGPointZero

        if result == .Success {
            if !AXValueGetValue(value as! AXValueRef, AXValueType.CGPoint, &topLeft) {
                topLeft = CGPointZero
            }
        }

        return topLeft
    }

    public func size() -> CGSize {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute, &value)

        var size = CGSizeZero

        if result == .Success {
            if !AXValueGetValue(value as! AXValueRef, AXValueType.CGSize, &size) {
                size = CGSizeZero
            }
        }

        return size
    }

    public func setFrame(frame: CGRect) {
        setSize(frame.size)
        setTopLeft(frame.origin)
        setSize(frame.size)
    }

    public func setTopLeft(topLeft: CGPoint) {
        var val = topLeft
        let value = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!.takeRetainedValue()
        AXUIElementSetAttributeValue(element, kAXPositionAttribute, value)
    }

    public func setSize(size: CGSize) {
        var val = size
        let value = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!.takeRetainedValue()
        AXUIElementSetAttributeValue(element, kAXSizeAttribute, value)
    }

    public func maximize() {
        setFrame(screen().frameIncludingDockAndMenu)
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

    public func isMain() -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXMainAttribute, &value)

        if result != .Success {
            return false
        }

        return (value as! NSNumber).boolValue
    }

    public func isStandard() -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute, &value)

        if result != .Success {
            value = ""
        }

        let subrole = value as! String
        return subrole == kAXStandardWindowSubrole
    }

    public func isMinimized() -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute, &value)

        if result != .Success {
            return false
        }

        return (value as! NSNumber).boolValue
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