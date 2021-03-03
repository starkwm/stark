import AppKit

let appObserverWindowKey = "observerWindowKey"

private let notifications = [
    NSAccessibility.Notification.windowCreated,
    NSAccessibility.Notification.uiElementDestroyed,
    NSAccessibility.Notification.focusedWindowChanged,
    NSAccessibility.Notification.windowMoved,
    NSAccessibility.Notification.windowResized,
    NSAccessibility.Notification.windowMiniaturized,
    NSAccessibility.Notification.windowDeminiaturized,
]

private let observerCallback: AXObserverCallback = { _, element, notification, _ in
    autoreleasepool {
        let window = Window(element: element)

        NotificationCenter.default.post(name: Notification.Name(rawValue: notification as String),
                                        object: nil,
                                        userInfo: [appObserverWindowKey: window])
    }
}

class AppObserver: NSObject {
    private var element: AXUIElement

    private var observer: AXObserver?

    init(app: NSRunningApplication) {
        element = AXUIElementCreateApplication(app.processIdentifier)

        super.init()

        AXObserverCreate(app.processIdentifier, observerCallback, &observer)

        NSWorkspace
            .shared
            .notificationCenter
            .addObserver(self,
                         selector: #selector(didReceiveNotification(_:)),
                         name: NSWorkspace.didLaunchApplicationNotification,
                         object: nil)

        register()
    }

    deinit {
        if let observer = observer {
            notifications.forEach { AXObserverRemoveNotification(observer, element, $0.rawValue as CFString) }
        }

        NSWorkspace
            .shared
            .notificationCenter
            .removeObserver(self, name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    }

    private func register() {
        if let observer = observer {
            CFRunLoopAddSource(CFRunLoopGetCurrent(),
                               AXObserverGetRunLoopSource(observer),
                               CFRunLoopMode.defaultMode)

            notifications.forEach { AXObserverAddNotification(observer, element, $0.rawValue as CFString, nil) }
        }
    }

    @objc
    func didReceiveNotification(_: Notification) {
        if observer != nil {
            register()
        }
    }
}
