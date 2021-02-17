import AppKit

let starkDidStartLaunch = "starkDidLauncbNotification"

enum EventHelper {
    static let notificationToNotificationCenter: [String: NotificationCenter] = {
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter

        return [
            NSWorkspace.activeSpaceDidChangeNotification.rawValue: workspaceNotificationCenter,
            NSWorkspace.didLaunchApplicationNotification.rawValue: workspaceNotificationCenter,
            NSWorkspace.didTerminateApplicationNotification.rawValue: workspaceNotificationCenter,
            NSWorkspace.didActivateApplicationNotification.rawValue: workspaceNotificationCenter,
            NSWorkspace.didHideApplicationNotification.rawValue: workspaceNotificationCenter,
            NSWorkspace.didUnhideApplicationNotification.rawValue: workspaceNotificationCenter,
        ]
    }()

    static let eventToNotification: [String: String] = [
        "starkDidLaunch": starkDidStartLaunch,

        "screensDidChange": NSApplication.didChangeScreenParametersNotification.rawValue,

        "spaceDidChange": NSWorkspace.activeSpaceDidChangeNotification.rawValue,

        "applicationDidLaunch": NSWorkspace.didLaunchApplicationNotification.rawValue,
        "applicationDidTerminate": NSWorkspace.didTerminateApplicationNotification.rawValue,
        "applicationDidActivate": NSWorkspace.didActivateApplicationNotification.rawValue,
        "applicationDidHide": NSWorkspace.didHideApplicationNotification.rawValue,
        "applicationDidShow": NSWorkspace.didUnhideApplicationNotification.rawValue,

        "windowDidOpen": NSAccessibility.Notification.windowCreated.rawValue,
        "windowDidClose": NSAccessibility.Notification.uiElementDestroyed.rawValue,
        "windowDidFocus": NSAccessibility.Notification.focusedWindowChanged.rawValue,
        "windowDidMove": NSAccessibility.Notification.windowMoved.rawValue,
        "windowDidResize": NSAccessibility.Notification.windowResized.rawValue,
        "windowDidMinimize": NSAccessibility.Notification.windowMiniaturized.rawValue,
        "windowDidUnminimize": NSAccessibility.Notification.windowDeminiaturized.rawValue,
    ]

    static func notificationCenter(for notification: String) -> NotificationCenter {
        if let notificationCenter = notificationToNotificationCenter[notification] {
            return notificationCenter
        }

        return NotificationCenter.default
    }

    static func notification(for event: String) -> String {
        if let notifiction = eventToNotification[event] {
            return notifiction
        }

        return ""
    }
}
