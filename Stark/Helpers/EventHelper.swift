import AppKit

public let starkStartNotification = "starkStartNotification"

open class EventHelper {
    fileprivate static let notificationToNotificationCenter: [String: NotificationCenter] = {
        let workspaceNotificationCenter = NSWorkspace.shared().notificationCenter

        return [
            NSNotification.Name.NSWorkspaceDidLaunchApplication.rawValue: workspaceNotificationCenter,
            NSNotification.Name.NSWorkspaceDidTerminateApplication.rawValue: workspaceNotificationCenter,
            NSNotification.Name.NSWorkspaceDidActivateApplication.rawValue: workspaceNotificationCenter,
            NSNotification.Name.NSWorkspaceDidHideApplication.rawValue: workspaceNotificationCenter,
            NSNotification.Name.NSWorkspaceDidUnhideApplication.rawValue: workspaceNotificationCenter,
        ]
    }()

    fileprivate static let eventToNotification: [String: String] = [
        "starkDidLaunch": starkStartNotification,
        
        "screensDidChange": NSNotification.Name.NSApplicationDidChangeScreenParameters.rawValue,
        
        "applicationDidLaunch": NSNotification.Name.NSWorkspaceDidLaunchApplication.rawValue,
        "applicationDidTerminate": NSNotification.Name.NSWorkspaceDidTerminateApplication.rawValue,
        "applicationDidActivate": NSNotification.Name.NSWorkspaceDidActivateApplication.rawValue,
        "applicationDidHide": NSNotification.Name.NSWorkspaceDidHideApplication.rawValue,
        "applicationDidShow": NSNotification.Name.NSWorkspaceDidUnhideApplication.rawValue,
        
        "windowDidOpen": NSAccessibilityWindowCreatedNotification,
        "windowDidClose": NSAccessibilityUIElementDestroyedNotification,
        "windowDidFocus": NSAccessibilityFocusedWindowChangedNotification,
        "windowDidMove": NSAccessibilityWindowMovedNotification,
        "windowDidResize": NSAccessibilityWindowResizedNotification,
        "windowDidMinimize": NSAccessibilityWindowMiniaturizedNotification,
        "windowDidUnminimize": NSAccessibilityWindowDeminiaturizedNotification,
    ]

    open static func notificationCenterForNotification(notification: String) -> NotificationCenter {
        if let notificationCenter = notificationToNotificationCenter[notification] {
            return notificationCenter
        }

        return NotificationCenter.default
    }

    open static func notificationForEvent(event: String) -> String {
        if let notifiction = eventToNotification[event] {
            return notifiction
        }

        return ""
    }
}
