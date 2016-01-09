import AppKit
import JavaScriptCore

@objc protocol WindowJSExport: JSExport {
    static func allWindows() -> [Window]
    static func visibleWindows() -> [Window]
    static func focusedWindow() -> Window?
}

public class Window: NSObject {
    private var element: AXUIElementRef

    init(element: AXUIElementRef) {
        self.element = element
    }
}
