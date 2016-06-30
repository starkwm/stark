import AppKit

public let AppObserverWindowKey = "ObserverWindowKey"

public class AppObserver {
    private static let notifications = [
        NSAccessibilityWindowCreatedNotification,
        NSAccessibilityUIElementDestroyedNotification,
        NSAccessibilityFocusedWindowChangedNotification,
        NSAccessibilityWindowMovedNotification,
        NSAccessibilityWindowResizedNotification,
        NSAccessibilityWindowMiniaturizedNotification,
        NSAccessibilityWindowDeminiaturizedNotification,
    ]

    private var element: AXUIElementRef

    private var observer: AXObserverRef? = nil

    init(app: NSRunningApplication) {
        element = AXUIElementCreateApplication(app.processIdentifier).takeRetainedValue()

        let callback: AXObserverCallback = { _, element, notification, _ in
            autoreleasepool {
                let window = Window(element: element)

                NSNotificationCenter
                    .defaultCenter()
                    .postNotificationName(notification as String, object: nil, userInfo: [AppObserverWindowKey: window])
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
                AXObserverGetRunLoopSource(observer!).takeUnretainedValue(),
                kCFRunLoopDefaultMode
            )
        }
    }

    private func addNotification(notification: String) {
        if observer != nil {
            AXObserverAddNotification(observer!, element, notification, nil)
        }
    }

    private func removeNotification(notification: String) {
        if observer != nil {
            AXObserverRemoveNotification(observer!, element, notification)
        }
    }

    private func setup() {
        if observer != nil {
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer!).takeUnretainedValue(),
                kCFRunLoopDefaultMode
            )
        }

        AppObserver.notifications.forEach { addNotification($0) }
    }
}