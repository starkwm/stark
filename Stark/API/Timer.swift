import AppKit
import JavaScriptCore

@objc
protocol TimerJSExport: JSExport {
    init(interval: TimeInterval, repeats: Bool, callback: JSValue)

    func stop()
}

public class Timer: Handler, TimerJSExport, HashableJSExport {
    /// Instance Variables

    private var timer: Foundation.Timer?

    /// Instance Functions

    public required init(interval: TimeInterval, repeats: Bool, callback: JSValue) {
        super.init()

        timer = Foundation.Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(timerDidFire), userInfo: nil, repeats: repeats)

        manageCallback(callback)
    }

    public func stop() {
        timer?.invalidate()
    }

    @objc
    func timerDidFire() {
        call()
    }
}
