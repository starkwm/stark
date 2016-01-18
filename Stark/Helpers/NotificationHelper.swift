import Foundation

class NotificationHelper {
    static func deliver(message: String) {
        let notification = NSUserNotification()
        notification.informativeText = message

        NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(notification)
    }
}