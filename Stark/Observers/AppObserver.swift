import AppKit

public let appObserverWindowKey = "observerWindowKey"

private let notifications = [
    NSAccessibilityNotificationName.windowCreated,
    NSAccessibilityNotificationName.uiElementDestroyed,
    NSAccessibilityNotificationName.focusedWindowChanged,
    NSAccessibilityNotificationName.windowMoved,
    NSAccessibilityNotificationName.windowResized,
    NSAccessibilityNotificationName.windowMiniaturized,
    NSAccessibilityNotificationName.windowDeminiaturized,
]

private let observerCallback: AXObserverCallback = { _, element, notification, _ in
    autoreleasepool {
        let window = Window(element: element)

        NotificationCenter.default.post(name: Notification.Name(rawValue: notification as String), object: nil, userInfo: [appObserverWindowKey: window])
    }
}

private let notificationCenter = NSWorkspace.shared.notificationCenter

open class AppObserver: NSObject {
    fileprivate var element: AXUIElement

    fileprivate var observer: AXObserver?

    init(app: NSRunningApplication) {
        element = AXUIElementCreateApplication(app.processIdentifier)

        super.init()

        notificationCenter.addObserver(self, selector: #selector(AppObserver.didReceiveNotification(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)

        AXObserverCreate(app.processIdentifier, observerCallback, &observer)
    }

    deinit {
        if observer != nil {
            notifications.forEach { remove(notification: $0.rawValue) }

            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer!), CFRunLoopMode.defaultMode)
        }

        notificationCenter.removeObserver(self, name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    }

    fileprivate func add(notification: String) {
        if observer != nil {
            AXObserverAddNotification(observer!, element, notification as CFString, nil)
        }
    }

    fileprivate func remove(notification: String) {
        if observer != nil {
            AXObserverRemoveNotification(observer!, element, notification as CFString)
        }
    }

    @objc
    func didReceiveNotification(_: Notification) {
        if observer != nil {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer!), CFRunLoopMode.defaultMode)

            notifications.forEach { add(notification: $0.rawValue) }
        }
    }
}
