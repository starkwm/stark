//
//  Timer.swift
//  Stark
//
//  Created by Tom Bell on 22/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit
import JavaScriptCore

public class Timer: Handler, TimerJSExport, HashableJSExport {
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

    public func stop() {
        timer?.invalidate()
    }

    @objc
    func timerDidFire() {
        call(withArguments: [callback!])
    }
}
