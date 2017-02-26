import AppKit

public let appObserverWindowKey = "observerWindowKey"

fileprivate let notifications = [
    NSAccessibilityWindowCreatedNotification,
    NSAccessibilityUIElementDestroyedNotification,
    NSAccessibilityFocusedWindowChangedNotification,
    NSAccessibilityWindowMovedNotification,
    NSAccessibilityWindowResizedNotification,
    NSAccessibilityWindowMiniaturizedNotification,
    NSAccessibilityWindowDeminiaturizedNotification,
]

fileprivate let observerCallback: AXObserverCallback = { _, element, notification, _ in
    autoreleasepool {
        let window = Window(element: element)

        NotificationCenter.default.post(name: Notification.Name(rawValue: notification as String), object: nil, userInfo: [appObserverWindowKey: window])
    }
}

fileprivate let notificationCenter = NSWorkspace.shared().notificationCenter

open class AppObserver: NSObject {
    fileprivate var element: AXUIElement

    fileprivate var observer: AXObserver?

    init(app: NSRunningApplication) {
        element = AXUIElementCreateApplication(app.processIdentifier)

        super.init()

        notificationCenter.addObserver(self, selector: #selector(AppObserver.didReceiveNotification(_:)), name: .NSWorkspaceDidLaunchApplication, object: nil)

        AXObserverCreate(app.processIdentifier, observerCallback, &observer)
    }

    deinit {
        if observer != nil {
            notifications.forEach { remove(notification: $0) }

            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer!), CFRunLoopMode.defaultMode)
        }

        notificationCenter.removeObserver(self, name: .NSWorkspaceDidLaunchApplication, object: nil)
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

    func didReceiveNotification(_: Notification) {
        if observer != nil {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer!), CFRunLoopMode.defaultMode)

            notifications.forEach { add(notification: $0) }
        }
    }
}
