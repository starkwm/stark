import AppKit
import JavaScriptCore

private let starkVisibilityOptionsKey = "visible"

private let SLSScreenIDKey = "Display Identifier"
private let SLSSpaceIDKey = "ManagedSpaceID"
private let SLSSpacesKey = "Spaces"

public class Space: NSObject, SpaceJSExport {
    private static let connectionID = SLSMainConnectionID()

    public static func all() -> [Space] {
        var spaces: [Space] = []

        let displaySpacesInfo = SLSCopyManagedDisplaySpaces(connectionID).takeRetainedValue() as NSArray

        displaySpacesInfo.forEach {
            guard let spacesInfo = $0 as? [String: AnyObject] else {
                return
            }

            guard let identifiers = spacesInfo[SLSSpacesKey] as? [[String: AnyObject]] else {
                return
            }

            identifiers.forEach {
                guard let identifier = $0[SLSSpaceIDKey] as? uint64 else {
                    return
                }

                spaces.append(Space(identifier: identifier))
            }
        }

        return spaces
    }

    public static func active() -> Space {
        Space(identifier: SLSGetActiveSpace(connectionID))
    }

    static func current(for screen: NSScreen) -> Space? {
        let identifier = SLSManagedDisplayGetCurrentSpace(connectionID, screen.identifier as CFString)

        return Space(identifier: identifier)
    }

    static func spaces(for window: Window) -> [Space] {
        var spaces: [Space] = []

        let identifiers = SLSCopySpacesForWindows(connectionID,
                                                  7,
                                                  [window.identifier] as CFArray).takeRetainedValue() as NSArray

        all().forEach {
            if identifiers.contains($0.identifier) {
                spaces.append(Space(identifier: $0.identifier))
            }
        }

        return spaces
    }

    init(identifier: uint64) {
        self.identifier = identifier
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let space = object as? Space else {
            return false
        }

        return identifier == space.identifier
    }

    public var identifier: uint64

    public var isNormal: Bool {
        SLSSpaceGetType(Space.connectionID, identifier) == 0
    }

    public var isFullscreen: Bool {
        SLSSpaceGetType(Space.connectionID, identifier) == 4
    }

    public func screens() -> [NSScreen] {
        if !NSScreen.screensHaveSeparateSpaces {
            return NSScreen.screens
        }

        let displaySpacesInfo = SLSCopyManagedDisplaySpaces(Space.connectionID).takeRetainedValue() as NSArray

        var screen: NSScreen?

        displaySpacesInfo.forEach {
            guard let spacesInfo = $0 as? [String: AnyObject] else {
                return
            }

            guard let screenIdentifier = spacesInfo[SLSScreenIDKey] as? String else {
                return
            }

            guard let identifiers = spacesInfo[SLSSpacesKey] as? [[String: AnyObject]] else {
                return
            }

            identifiers.forEach {
                guard let identifier = $0[SLSSpaceIDKey] as? uint64 else {
                    return
                }

                if identifier == self.identifier {
                    screen = NSScreen.screen(for: screenIdentifier)
                }
            }
        }

        if screen == nil {
            return []
        }

        return [screen!]
    }

    public func windows(_ options: [String: AnyObject] = [:]) -> [Window] {
        Window.all(options).filter { $0.spaces().contains(self) }
    }

    public func addWindows(_ windows: [Window]) {
        SLSAddWindowsToSpaces(Space.connectionID, windows.map(\.identifier) as CFArray, [identifier] as CFArray)
    }

    public func removeWindows(_ windows: [Window]) {
        SLSRemoveWindowsFromSpaces(Space.connectionID, windows.map(\.identifier) as CFArray, [identifier] as CFArray)
    }
}
