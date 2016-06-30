import AppKit
import JavaScriptCore

@objc protocol EventJSExport: JSExport {
    @objc(on::) static func on(event: String, callback: JSValue) -> Event

    var name: String { get }
}

public class Event: Handler, EventJSExport {
    public var name: String

    private var notification: String
    private var notificationCenter: NSNotificationCenter

    @objc(on::) public static func on(event: String, callback: JSValue) -> Event {
        return Event(event: event, callback: callback)
    }

    init(event: String, callback: JSValue) {
        name = event

        notification = EventHelper.notificationForEvent(event)
        notificationCenter = EventHelper.notificationCenterForNotification(notification)

        super.init()

        manageCallback(callback)

        notificationCenter.addObserver(self, selector: #selector(Event.didReceiveNotification(_:)), name: notification, object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self, name: notification, object: nil)
    }

    func didReceiveNotification(notification: NSNotification) {
        guard let userInfo = notification.userInfo else {
            call()
            return
        }

        if let runningApp = userInfo[NSWorkspaceApplicationKey] as? NSRunningApplication {
            let app = Application(app: runningApp)
            callWithArguments([app])
            return
        }

        if let window = userInfo[AppObserverWindowKey] as? Window {
            callWithArguments([window])
            return
        }
    }
}