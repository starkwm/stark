import AppKit
import JavaScriptCore

@objc
protocol TimerJSExport: JSExport {
    init(interval: TimeInterval, repeats: Bool, callback: JSValue)

    var id: Int { get }

    func stop()
}
