import AppKit
import JavaScriptCore

@objc
protocol SpaceJSExport: JSExport {
    static func active() -> Space
    static func all() -> [Space]

    var isNormal: Bool { get }
    var isFullscreen: Bool { get }

    func screens() -> [NSScreen]

    func windows() -> [Window]
    func windows(_ options: [String: AnyObject]) -> [Window]

    func addWindows(_ windows: [Window])
    func removeWindows(_ windows: [Window])
}
