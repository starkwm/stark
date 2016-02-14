import AppKit

public let StarkStartNotification = "StarkStartNotification"

public class EventHelper {
    private static let notificationToNotificationCenter: [String: NSNotificationCenter] = {
        let workspaceNotificationCenter = NSWorkspace.sharedWorkspace().notificationCenter

        return [
            NSWorkspaceDidLaunchApplicationNotification: workspaceNotificationCenter,
            NSWorkspaceDidTerminateApplicationNotification: workspaceNotificationCenter,
            NSWorkspaceDidActivateApplicationNotification: workspaceNotificationCenter,
            NSWorkspaceDidHideApplicationNotification: workspaceNotificationCenter,
            NSWorkspaceDidUnhideApplicationNotification: workspaceNotificationCenter,
        ]
    }()

    private static let eventToNotification: [String: String] = [
        // stark
        "starkDidLaunch": StarkStartNotification,

        // screen
        "screensDidChange": NSApplicationDidChangeScreenParametersNotification,

        // application
        "applicationDidLaunch": NSWorkspaceDidLaunchApplicationNotification,
        "applicationDidTerminate": NSWorkspaceDidTerminateApplicationNotification,
        "applicationDidActivate": NSWorkspaceDidActivateApplicationNotification,
        "applicationDidHide": NSWorkspaceDidHideApplicationNotification,
        "applicationDidShow": NSWorkspaceDidUnhideApplicationNotification,

        // window
        "windowDidOpen": NSAccessibilityWindowCreatedNotification,
        "windowDidClose": NSAccessibilityUIElementDestroyedNotification,
        "windowDidFocus": NSAccessibilityFocusedWindowChangedNotification,
        "windowDidMove": NSAccessibilityWindowMovedNotification,
        "windowDidResize": NSAccessibilityWindowResizedNotification,
        "windowDidMinimize": NSAccessibilityWindowMiniaturizedNotification,
        "windowDidUnminimize": NSAccessibilityWindowDeminiaturizedNotification,
    ]

    public static func notificationCenterForNotification(notification: String) -> NSNotificationCenter {
        if let notificationCenter = notificationToNotificationCenter[notification] {
            return notificationCenter
        }

        return NSNotificationCenter.defaultCenter()
    }

    public static func notificationForEvent(event: String) -> String {
        if let notifiction = eventToNotification[event] {
            return notifiction
        }

        return ""
    }
}