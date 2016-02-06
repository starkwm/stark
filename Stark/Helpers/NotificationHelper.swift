import Foundation

public class NotificationHelper {
    public static func deliver(message: String) {
        let notification = NSUserNotification()
        notification.informativeText = message

        NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(notification)
    }
}