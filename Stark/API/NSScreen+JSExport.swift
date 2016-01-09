import AppKit
import JavaScriptCore

@objc protocol NSScreenJSExport: JSExport {
    func frameIncludingDockAndMenu() -> CGRect
    func frameWithoutDockOrMenu() -> CGRect

    func nextScreen() -> NSScreen?
    func prevScreen() -> NSScreen?
}

extension NSScreen: NSScreenJSExport {
    public func frameIncludingDockAndMenu() -> CGRect {
        let primaryScreen = NSScreen.screens()!.first
        var f = frame
        f.origin.y = NSHeight(primaryScreen!.frame) - NSHeight(f) - f.origin.y
        return f
    }

    public func frameWithoutDockOrMenu() -> CGRect {
        let primaryScreen = NSScreen.screens()!.first
        var f = visibleFrame
        f.origin.y = NSHeight(primaryScreen!.frame) - NSHeight(f) - f.origin.y
        return f
    }

    public func nextScreen() -> NSScreen? {
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

    public func prevScreen() -> NSScreen? {
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
