import AppKit
import JavaScriptCore

@objc
protocol TimerJSExport: JSExport {
    init(interval: TimeInterval, repeats: Bool, callback: JSValue)

    func stop()
}

open class Timer: Handler, TimerJSExport, HashableJSExport {
    private var timer: Foundation.Timer?

    public required init(interval: TimeInterval, repeats: Bool, callback: JSValue) {
        super.init()

        timer = Foundation.Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(timerDidFire), userInfo: nil, repeats: repeats)

        manageCallback(callback)
    }

    open func stop() {
        timer?.invalidate()
    }

    @objc
    func timerDidFire() {
        callWithArguments(nil)
    }
}
