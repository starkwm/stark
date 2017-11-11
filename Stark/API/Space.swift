import AppKit
import JavaScriptCore

private let CGSSpaceIDKey = "ManagedSpaceID"
private let CGSSpacesKey = "Spaces"

@objc
protocol SpaceJSExport: JSExport {
    static func active() -> Space
    static func all() -> [Space]
    static func currentSpace(for screen: NSScreen) -> Space
}

open class Space: NSObject, SpaceJSExport {
    public var identifier: CGSSpaceID

    open static func active() -> Space {
        return Space(identifier: CGSGetActiveSpace(CGSMainConnectionID()))
    }

    open static func all() -> [Space] {
        var spaces = [Space]()

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

    open static func currentSpace(for screen: NSScreen) -> Space {
        let identifier = CGSManagedDisplayGetCurrentSpace(CGSMainConnectionID(), screen.identifier as CFString)
        return Space(identifier: identifier)
    }

    init(identifier: UInt) {
        self.identifier = identifier
    }
}
