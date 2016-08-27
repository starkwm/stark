import AppKit
import JavaScriptCore

@objc protocol NSScreenJSExport: JSExport {
    static func all() -> [NSScreen]
    static func focused() -> NSScreen?

    var frameIncludingDockAndMenu: CGRect { get }
    var frameWithoutDockOrMenu: CGRect { get }

    var nextScreen: NSScreen? { get }
    var prevScreen: NSScreen? { get }
}

extension NSScreen: NSScreenJSExport {
    public static func all() -> [NSScreen] {
        return screens() ?? []
    }

    public static func focused() -> NSScreen? {
        return mainScreen()
    }

    public var frameIncludingDockAndMenu: CGRect {
        get {
            let primaryScreen = NSScreen.screens()!.first
            var f = frame
            f.origin.y = primaryScreen!.frame.height - f.height - f.origin.y
            return f
        }
    }

    public var frameWithoutDockOrMenu: CGRect {
        get {
            let primaryScreen = NSScreen.screens()!.first
            var f = visibleFrame
            f.origin.y = primaryScreen!.frame.height - f.height - f.origin.y
            return f
        }
    }

    public var nextScreen: NSScreen? {
        get {
            let screens = NSScreen.screens()!

            if var index = screens.indexOf(self) {
                index += 1

                if index == screens.count {
                    index = 0
                }

                return screens[index]
            }

            return nil
        }
    }

    public var prevScreen: NSScreen? {
        get {
            let screens = NSScreen.screens()!

            if var index = screens.indexOf(self) {
                index -= 1

                if index == -1 {
                    index = screens.count - 1
                }

                return screens[index]
            }

            return nil
        }
    }
}
