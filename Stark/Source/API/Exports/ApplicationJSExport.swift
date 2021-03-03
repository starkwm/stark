import JavaScriptCore

@objc
protocol ApplicationJSExport: JSExport {
    static func find(_ name: String) -> App?
    static func all() -> [App]
    static func focused() -> App?

    var name: String { get }

    var bundleId: String { get }
    var processId: pid_t { get }

    var isActive: Bool { get }
    var isHidden: Bool { get }
    var isTerminated: Bool { get }

    func windows(_ options: [String: AnyObject]) -> [Window]

    func activate() -> Bool
    func focus() -> Bool

    func show() -> Bool
    func hide() -> Bool

    func terminate() -> Bool
}
