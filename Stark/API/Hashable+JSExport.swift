//
//  Hashable+JSExport.swift
//  Stark
//
//  Created by Tom Bell on 22/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc
protocol HashableJSExport: JSExport {
    var hashValue: Int { get }
}
