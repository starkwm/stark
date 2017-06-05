import AppKit
import JavaScriptCore

@objc
protocol EventJSExport: JSExport {
    init(event: String, callback: JSValue)

    var name: String { get }
}

open class Event: Handler, EventJSExport, HashableJSExport {
    open var name: String

    fileprivate var notification: String
    fileprivate var notificationCenter: NotificationCenter

    public required init(event: String, callback: JSValue) {
        name = event

        notification = EventHelper.notification(for: event)
        notificationCenter = EventHelper.notificationCenter(for: notification)

        super.init()

        manageCallback(callback)

        notificationCenter.addObserver(self, selector: #selector(Event.didReceiveNotification(_:)), name: NSNotification.Name(rawValue: notification), object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: notification), object: nil)
    }

    @objc
    func didReceiveNotification(_ notification: Notification) {
        guard let userInfo = (notification as NSNotification).userInfo else {
            call()
            return
        }

        if let runningApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
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
