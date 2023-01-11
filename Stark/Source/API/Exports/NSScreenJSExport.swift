import AppKit
import JavaScriptCore

@objc
protocol NSScreenJSExport: JSExport {
    static func all() -> [NSScreen]
    static func focused() -> NSScreen?

    var identifier: String { get }

    var frameIncludingDockAndMenu: CGRect { get }
    var frameWithoutDockOrMenu: CGRect { get }

    var flippedFrame: CGRect { get }
    var flippedVisibleFrame: CGRect { get }

    var next: NSScreen? { get }
    var previous: NSScreen? { get }

    func currentSpace() -> Space?
    func spaces() -> [Space]
}
