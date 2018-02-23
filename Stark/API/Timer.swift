//
//  Timer.swift
//  Stark
//
//  Created by Tom Bell on 22/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit
import JavaScriptCore

@objc
protocol TimerJSExport: JSExport {
    init(interval: TimeInterval, repeats: Bool, callback: JSValue)

    func stop()
}

public class Timer: Handler, TimerJSExport, HashableJSExport {
    /// Initializers

    public required init(interval: TimeInterval, repeats: Bool, callback: JSValue) {
        super.init()

        timer = Foundation.Timer.scheduledTimer(timeInterval: interval,
                                                target: self,
                                                selector: #selector(timerDidFire),
                                                userInfo: nil,
                                                repeats: repeats)

        manageCallback(callback)
    }

    /// Instance Variables

    private var timer: Foundation.Timer?

    /// Instance Functions

    public func stop() {
        timer?.invalidate()
    }

    @objc
    func timerDidFire() {
        call(withArguments: [callback!])
    }
}
