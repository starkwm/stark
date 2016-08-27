import AppKit
import JavaScriptCore

@objc protocol TimerJSExport: JSExport {
    func stop()
}

public class Timer: Handler, TimerJSExport, HashableJSExport {
    private var timer: NSTimer? = nil

    init(interval: NSTimeInterval, repeats: Bool, callback: JSValue) {
        super.init()

        timer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: #selector(timerDidFire), userInfo: nil, repeats: repeats)

        manageCallback(callback)
    }

    public func stop() {
        timer?.invalidate()
    }

    func timerDidFire() {
        callWithArguments(nil)
    }
}
