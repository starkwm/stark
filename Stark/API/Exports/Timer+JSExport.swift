//
//  Timer+JSExport.swift
//  Stark
//
//  Created by Tom Bell on 28/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit
import JavaScriptCore

@objc
protocol TimerJSExport: JSExport {
    init(interval: TimeInterval, repeats: Bool, callback: JSValue)

    func stop()
}
