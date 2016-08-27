import AppKit
import JavaScriptCore

@objc protocol EventJSExport: JSExport {
    init(event: String, callback: JSValue)

    var name: String { get }
}

public class Event: Handler, EventJSExport, HashableJSExport {
    public var name: String

    private var notification: String
    private var notificationCenter: NSNotificationCenter

    public required init(event: String, callback: JSValue) {
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

        if let window = userInfo[appObserverWindowKey] as? Window {
            callWithArguments([window])
            return
        }
    }
}
