import AppKit
import JavaScriptCore

private let CGSSpaceIDKey = "ManagedSpaceID"
private let CGSSpacesKey = "Spaces"

@objc
protocol SpaceJSExport: JSExport {
    static func active() -> Space
    static func all() -> [Space]

    static func currentSpace(for screen: NSScreen) -> Space
    static func spaces(for window: Window) -> [Space]
}

open class Space: NSObject, SpaceJSExport {
    private var identifier: CGSSpaceID

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

    open static func spaces(for window: Window) -> [Space] {
        let identifiers = CGSCopySpacesForWindows(CGSMainConnectionID(), kCGSAllSpacesMask, [window.identifier] as CFArray).takeRetainedValue() as NSArray
        return all().filter { identifiers.contains($0.identifier) }
    }

    init(identifier: CGSSpaceID) {
        self.identifier = identifier
    }
}
