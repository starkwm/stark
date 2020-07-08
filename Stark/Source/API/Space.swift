import AppKit
import JavaScriptCore

private let starkVisibilityOptionsKey = "visible"

private let CGSScreenIDKey = "Display Identifier"
private let CGSSpaceIDKey = "ManagedSpaceID"
private let CGSSpacesKey = "Spaces"

public class Space: NSObject, SpaceJSExport {
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

    static func current(for screen: NSScreen) -> Space? {
        let identifier = CGSManagedDisplayGetCurrentSpace(CGSMainConnectionID(), screen.identifier as CFString)

        return Space(identifier: identifier)
    }

    static func spaces(for window: Window) -> [Space] {
        var spaces: [Space] = []

        let identifiers = CGSCopySpacesForWindows(CGSMainConnectionID(),
                                                  kCGSAllSpacesMask,
                                                  [window.identifier] as CFArray).takeRetainedValue() as NSArray

        all().forEach {
            if identifiers.contains($0.identifier) {
                spaces.append(Space(identifier: $0.identifier))
            }
        }

        return spaces
    }

    init(identifier: CGSSpaceID) {
        self.identifier = identifier
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let space = object as? Space else {
            return false
        }

        return identifier == space.identifier
    }

    private var identifier: CGSSpaceID

    public var isNormal: Bool {
        return CGSSpaceGetType(CGSMainConnectionID(), identifier) == CGSSpaceTypeUser
    }

    public var isFullscreen: Bool {
        return CGSSpaceGetType(CGSMainConnectionID(), identifier) == CGSSpaceTypeFullscreen
    }

    public func screens() -> [NSScreen] {
        if !NSScreen.screensHaveSeparateSpaces {
            return NSScreen.screens
        }

        let displaySpacesInfo = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()).takeRetainedValue() as NSArray

        var screen: NSScreen?

        displaySpacesInfo.forEach {
            guard let spacesInfo = $0 as? [String: AnyObject] else {
                return
            }

            guard let screenIdentifier = spacesInfo[CGSScreenIDKey] as? String else {
                return
            }

            guard let identifiers = spacesInfo[CGSSpacesKey] as? [[String: AnyObject]] else {
                return
            }

            identifiers.forEach {
                guard let identifier = $0[CGSSpaceIDKey] as? CGSSpaceID else {
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

    public func windows() -> [Window] {
        return Window.all().filter { $0.spaces().contains(self) }
    }

    public func windows(_ options: [String: AnyObject]) -> [Window] {
        let visible = options[starkVisibilityOptionsKey] as? Bool ?? false

        if visible {
            return windows().filter { !$0.app.isHidden && $0.isStandard && !$0.isMinimized }
        }

        return windows()
    }

    public func addWindows(_ windows: [Window]) {
        CGSAddWindowsToSpaces(CGSMainConnectionID(),
                              windows.map { $0.identifier } as CFArray,
                              [identifier] as CFArray)
    }

    public func removeWindows(_ windows: [Window]) {
        CGSRemoveWindowsFromSpaces(CGSMainConnectionID(),
                                   windows.map { $0.identifier } as CFArray,
                                   [identifier] as CFArray)
    }
}
