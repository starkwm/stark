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

    private var observer: AXObserverRef?

    init(app: NSRunningApplication) {
        self.element = AXUIElementCreateApplication(app.processIdentifier).takeRetainedValue()

        let callback: AXObserverCallback = { _, element, notification, _ in
            autoreleasepool {
                let window = Window(element: element)

                NSNotificationCenter
                    .defaultCenter()
                    .postNotificationName(notification as String, object: nil, userInfo: [AppObserverWindowKey: window])
            }
        }

        var observer: AXObserverRef? = nil
        AXObserverCreate(app.processIdentifier, callback, &observer)

        self.observer = observer

        setup()
    }

    deinit {
        AppObserver.notifications.forEach {  removeNotification($0) }

        if self.observer != nil {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(self.observer!).takeUnretainedValue(),
                kCFRunLoopDefaultMode
            )
        }
    }

    private func addNotification(notification: String) {
        if self.observer != nil {
            AXObserverAddNotification(self.observer!, self.element, notification, nil)
        }
    }

    private func removeNotification(notification: String) {
        if self.observer != nil {
            AXObserverRemoveNotification(self.observer!, self.element, notification)
        }
    }

    private func setup() {
        if self.observer != nil {
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(self.observer!).takeUnretainedValue(),
                kCFRunLoopDefaultMode
            )
        }

        AppObserver.notifications.forEach { addNotification($0) }
    }
}