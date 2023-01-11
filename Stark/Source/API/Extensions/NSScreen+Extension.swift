import AppKit

private let NSScreenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

extension NSScreen: NSScreenJSExport {
    public static func all() -> [NSScreen] {
        screens
    }

    public static func focused() -> NSScreen? {
        main
    }

    public static func screen(for identifier: String) -> NSScreen? {
        screens.first { $0.identifier == identifier }
    }

    public var identifier: String {
        guard let number = deviceDescription[NSScreenNumberKey] as? NSNumber else {
            return ""
        }

        let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value).takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }

    @available(*, deprecated, message: "please use flippedFrame instead")
    public var frameIncludingDockAndMenu: CGRect {
        flippedFrame
    }

    public var flippedFrame: CGRect {
        let primaryScreen = NSScreen.screens.first
        var frame = frame
        frame.origin.y = primaryScreen!.frame.height - frame.height - frame.origin.y
        return frame
    }

    @available(*, deprecated, message: "please use flippedVisibleFrame instead")
    public var frameWithoutDockOrMenu: CGRect {
        flippedVisibleFrame
    }

    public var flippedVisibleFrame: CGRect {
        let primaryScreen = NSScreen.screens.first
        var frame = visibleFrame
        frame.origin.y = primaryScreen!.frame.height - frame.height - frame.origin.y
        return frame
    }

    public var next: NSScreen? {
        let screens = NSScreen.screens

        if var index = screens.firstIndex(of: self) {
            index += 1

            if index == screens.count {
                index = 0
            }

            return screens[index]
        }

        return nil
    }

    public var previous: NSScreen? {
        let screens = NSScreen.screens

        if var index = screens.firstIndex(of: self) {
            index -= 1

            if index == -1 {
                index = screens.count - 1
            }

            return screens[index]
        }

        return nil
    }

    public func currentSpace() -> Space? {
        Space.current(for: self)
    }

    public func spaces() -> [Space] {
        Space.all().filter { $0.screens().contains(self) }
    }
}
