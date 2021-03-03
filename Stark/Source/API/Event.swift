import AppKit
import JavaScriptCore

public class Event: Handler, EventJSExport {
    public required init(event: String, callback: JSValue) {
        name = event

        notification = EventHelper.notification(for: event)
        notificationCenter = EventHelper.notificationCenter(for: notification)

        super.init()

        manageCallback(callback)

        notificationCenter.addObserver(self,
                                       selector: #selector(didReceiveNotification(_:)),
                                       name: NSNotification.Name(rawValue: notification),
                                       object: nil)
    }

    deinit {
        disable()
    }

    private var notification: String
    private var notificationCenter: NotificationCenter

    public var id: Int {
        hashValue
    }

    public var name: String

    public func disable() {
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: notification), object: nil)
    }

    @objc
    func didReceiveNotification(_ notification: Notification) {
        guard let userInfo = (notification as NSNotification).userInfo else {
            call()
            return
        }

        if let runningApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            let app = App(app: runningApp)
            call(withArguments: [app])
            return
        }

        if let window = userInfo[appObserverWindowKey] as? Window {
            call(withArguments: [window])
            return
        }
    }
}
