//
//  Stark+JSExports.swift
//  Stark
//
//  Created by Tom Bell on 28/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import JavaScriptCore

@objc
protocol StarkJSExport: JSExport {
    func log(_ message: String)
    func reload()
    func run(_ command: String, _ arguments: [String]?)
}
