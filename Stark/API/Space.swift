//
//  Space.swift
//  Stark
//
//  Created by Tom Bell on 23/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit
import JavaScriptCore

private let starkVisibilityOptionsKey = "visible"

private let CGSScreenIDKey = "Display Identifier"
private let CGSSpaceIDKey = "ManagedSpaceID"
private let CGSSpacesKey = "Spaces"

@objc
protocol SpaceJSExport: JSExport {
    static func active() -> Space
    static func all() -> [Space]
}

public class Space: NSObject, SpaceJSExport {
    /// Static Functions

    public static func active() -> Space {
        return Space(identifier: CGSGetActiveSpace(CGSMainConnectionID()))
    }

    public static func all() -> [Space] {
        var spaces: [Space] = []

        let displaySpacesInfo = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()).takeRetainedValue() as NSArray

        displaySpacesInfo.forEach {
            guard let spacesInfo = $0 as? [String: AnyObject] else {
                return
            }

            guard let identifiers = spacesInfo[CGSSpacesKey] as? [[String: AnyObject]] else {
                return
            }

            identifiers.forEach {
                guard let identifier = $0[CGSSpaceIDKey] as? CGSSpaceID else {
                    return
                }

                spaces.append(Space(identifier: identifier))
            }
        }

        return spaces
    }

    /// Initializers

    init(identifier: CGSSpaceID) {
        self.identifier = identifier
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let space = object as? Space else {
            return false
        }

        return identifier == space.identifier
    }

    /// Instance Variables

    private var identifier: CGSSpaceID

    /// Instance Functions

    public var isNormal: Bool {
        return CGSSpaceGetType(CGSMainConnectionID(), identifier) == kCGSSpaceUser
    }

    public var isFullscreen: Bool {
        return CGSSpaceGetType(CGSMainConnectionID(), identifier) == kCGSSpaceFullScreen
    }
}
