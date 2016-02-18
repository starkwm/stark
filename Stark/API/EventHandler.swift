import AppKit
import JavaScriptCore

@objc protocol EventHandlerJSExport: JSExport {
    var name: String { get }
}

public class EventHandler: Handler, EventHandlerJSExport {
    public var name: String

    private var notification: String
    private var notificationCenter: NSNotificationCenter

    init(event: String, callback: JSValue) {
        self.name = event

        self.notification = EventHelper.notificationForEvent(event)
        self.notificationCenter = EventHelper.notificationCenterForNotification(self.notification)

        super.init()

        self.manageCallback(callback)

        self.notificationCenter.addObserver(self, selector: "didReceiveNotification:", name: self.notification, object: nil)
    }

    deinit {
        self.notificationCenter.removeObserver(self, name: self.notification, object: nil)
    }

    func didReceiveNotification(notification: NSNotification) {
        guard let userInfo = notification.userInfo else {
            self.call()
            return
        }

        if let runningApp = userInfo[NSWorkspaceApplicationKey] as? NSRunningApplication {
            let app = Application(app: runningApp)
            self.callWithArguments([app])
            return
        }

        if let window = userInfo[AppObserverWindowKey] as? Window {
            self.callWithArguments([window])
            return
        }
    }
}