import AppKit
import JavaScriptCore

@objc
protocol WindowJSExport: JSExport {
    static func all(_ options: [String: AnyObject]) -> [Window]
    static func focused() -> Window?

    var app: App { get }
    var screen: NSScreen { get }

    var title: String { get }

    var frame: CGRect { get }
    var topLeft: CGPoint { get }
    var size: CGSize { get }

    var isStandard: Bool { get }
    var isMain: Bool { get }
    var isFullscreen: Bool { get }
    var isMinimized: Bool { get }

    func setFrame(_ frame: CGRect)
    func setTopLeft(_ topLeft: CGPoint)
    func setSize(_ size: CGSize)

    func maximize()
    func minimize()
    func unminimize()

    func focus()

    func spaces() -> [Space]
}
