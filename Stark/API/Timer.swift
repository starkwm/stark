import AppKit
import JavaScriptCore

@objc protocol TimerJSExport: JSExport {
    @objc(every::) static func every(interval: NSTimeInterval, callback: JSValue) -> Timer
    @objc(after::) static func after(interval: NSTimeInterval, callback: JSValue) -> Timer

    func stop()
}

public class Timer: Handler, TimerJSExport {
    private var timer: NSTimer? = nil

    @objc(every::) public static func every(interval: NSTimeInterval, callback: JSValue) -> Timer {
        return Timer(interval: interval, repeats: true, callback: callback)
    }

    @objc(after::) public static func after(interval: NSTimeInterval, callback: JSValue) -> Timer {
        return Timer(interval: interval, repeats: false, callback: callback)
    }

    init(interval: NSTimeInterval, repeats: Bool, callback: JSValue) {
        super.init()

        timer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: #selector(self.timerDidFire), userInfo: nil, repeats: repeats)

        self.manageCallback(callback)
    }

    public func stop() {
        timer?.invalidate()
    }

    public func timerDidFire() {
        self.callWithArguments(nil)
    }
}