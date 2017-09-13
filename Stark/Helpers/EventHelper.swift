import AppKit

public let starkStartNotification = "starkStartNotification"

open class EventHelper {
    fileprivate static let notificationToNotificationCenter: [String: NotificationCenter] = {
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter

        return [
            NSWorkspace.didLaunchApplicationNotification.rawValue: workspaceNotificationCenter,
            NSWorkspace.didTerminateApplicationNotification.rawValue: workspaceNotificationCenter,
            NSWorkspace.didActivateApplicationNotification.rawValue: workspaceNotificationCenter,
            NSWorkspace.didHideApplicationNotification.rawValue: workspaceNotificationCenter,
            NSWorkspace.didUnhideApplicationNotification.rawValue: workspaceNotificationCenter,
        ]
    }()

    fileprivate static let eventToNotification: [String: String] = [
        "starkDidLaunch": starkStartNotification,

        "screensDidChange": NSApplication.didChangeScreenParametersNotification.rawValue,

        "applicationDidLaunch": NSWorkspace.didLaunchApplicationNotification.rawValue,
        "applicationDidTerminate": NSWorkspace.didTerminateApplicationNotification.rawValue,
        "applicationDidActivate": NSWorkspace.didActivateApplicationNotification.rawValue,
        "applicationDidHide": NSWorkspace.didHideApplicationNotification.rawValue,
        "applicationDidShow": NSWorkspace.didUnhideApplicationNotification.rawValue,

        "windowDidOpen": NSAccessibilityNotificationName.windowCreated.rawValue,
        "windowDidClose": NSAccessibilityNotificationName.uiElementDestroyed.rawValue,
        "windowDidFocus": NSAccessibilityNotificationName.focusedWindowChanged.rawValue,
        "windowDidMove": NSAccessibilityNotificationName.windowMoved.rawValue,
        "windowDidResize": NSAccessibilityNotificationName.windowResized.rawValue,
        "windowDidMinimize": NSAccessibilityNotificationName.windowMiniaturized.rawValue,
        "windowDidUnminimize": NSAccessibilityNotificationName.windowDeminiaturized.rawValue,
    ]

    open static func notificationCenter(for notification: String) -> NotificationCenter {
        if let notificationCenter = notificationToNotificationCenter[notification] {
            return notificationCenter
        }

        return NotificationCenter.default
    }

    open static func notification(for event: String) -> String {
        if let notifiction = eventToNotification[event] {
            return notifiction
        }

        return ""
    }
}
