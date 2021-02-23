import AppKit
import JavaScriptCore

public class Timer: Handler, TimerJSExport {
    public required init(interval: TimeInterval, repeats: Bool, callback: JSValue) {
        super.init()

        timer = Foundation.Timer.scheduledTimer(timeInterval: interval,
                                                target: self,
                                                selector: #selector(timerDidFire),
                                                userInfo: nil,
                                                repeats: repeats)

        manageCallback(callback)
    }

    private var timer: Foundation.Timer?

    public var id: Int {
        hashValue
    }

    public func stop() {
        timer?.invalidate()
    }

    @objc
    func timerDidFire() {
        call(withArguments: [callback!])
    }
}
