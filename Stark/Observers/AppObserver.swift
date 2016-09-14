import AppKit

public let appObserverWindowKey = "observerWindowKey"

open class AppObserver {
    fileprivate static let notifications = [
        NSAccessibilityWindowCreatedNotification,
        NSAccessibilityUIElementDestroyedNotification,
        NSAccessibilityFocusedWindowChangedNotification,
        NSAccessibilityWindowMovedNotification,
        NSAccessibilityWindowResizedNotification,
        NSAccessibilityWindowMiniaturizedNotification,
        NSAccessibilityWindowDeminiaturizedNotification,
    ]

    fileprivate var element: AXUIElement

    fileprivate var observer: AXObserver? = nil

    init(app: NSRunningApplication) {
        element = AXUIElementCreateApplication(app.processIdentifier)

        let callback: AXObserverCallback = { _, element, notification, _ in
            autoreleasepool {
                let window = Window(element: element)

                NotificationCenter.default
                    .post(name: Notification.Name(rawValue: notification as String), object: nil, userInfo: [appObserverWindowKey: window])
            }
        }

        AXObserverCreate(app.processIdentifier, callback, &observer)

        setup()
    }

    deinit {
        AppObserver.notifications.forEach {  removeNotification($0) }

        if observer != nil {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer!),
                CFRunLoopMode.defaultMode
            )
        }
    }

    fileprivate func addNotification(_ notification: String) {
        if observer != nil {
            AXObserverAddNotification(observer!, element, notification as CFString, nil)
        }
    }

    fileprivate func removeNotification(_ notification: String) {
        if observer != nil {
            AXObserverRemoveNotification(observer!, element, notification as CFString)
        }
    }

    fileprivate func setup() {
        if observer != nil {
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer!),
                CFRunLoopMode.defaultMode
            )
        }

        AppObserver.notifications.forEach { addNotification($0) }
    }
}
