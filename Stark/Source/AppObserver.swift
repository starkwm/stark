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

private let notificationCenter = NSWorkspace.shared.notificationCenter

class AppObserver: NSObject {
    private var element: AXUIElement

    private var observer: AXObserver?

    init(app: NSRunningApplication) {
        element = AXUIElementCreateApplication(app.processIdentifier)

        super.init()

        notificationCenter.addObserver(self,
                                       selector: #selector(didReceiveNotification(_:)),
                                       name: NSWorkspace.didLaunchApplicationNotification,
                                       object: nil)

        AXObserverCreate(app.processIdentifier, observerCallback, &observer)
        register()
    }

    deinit {
        if observer != nil {
            notifications.forEach { remove(notification: $0.rawValue) }

            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                                  AXObserverGetRunLoopSource(observer!),
                                  CFRunLoopMode.defaultMode)
        }

        notificationCenter.removeObserver(self, name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    }

    private func add(notification: String) {
        if observer != nil {
            AXObserverAddNotification(observer!, element, notification as CFString, nil)
        }
    }

    private func remove(notification: String) {
        if observer != nil {
            AXObserverRemoveNotification(observer!, element, notification as CFString)
        }
    }

    private func register() {
        if observer != nil {
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer!), CFRunLoopMode.defaultMode)

            notifications.forEach { add(notification: $0.rawValue) }
        }
    }

    @objc
    func didReceiveNotification(_: Notification) {
        register()
    }
}
