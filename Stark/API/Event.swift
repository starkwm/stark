//
//  Event.swift
//  Stark
//
//  Created by Tom Bell on 22/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit
import JavaScriptCore

@objc
protocol EventJSExport: JSExport {
    init(event: String, callback: JSValue)

    var name: String { get }

    func disable()
}

public class Event: Handler, EventJSExport, HashableJSExport {
    /// Initializers

    public required init(event: String, callback: JSValue) {
        name = event

        notification = EventHelper.notification(for: event)
        notificationCenter = EventHelper.notificationCenter(for: notification)

        super.init()

        manageCallback(callback)

        notificationCenter.addObserver(self,
                                       selector: #selector(Event.didReceiveNotification(_:)),
                                       name: NSNotification.Name(rawValue: notification),
                                       object: nil)
    }

    deinit {
        disable()
    }

    /// Instance Variables

    private var notification: String

    private var notificationCenter: NotificationCenter

    public var name: String

    /// Instance Functions

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
            let app = Application(app: runningApp)
            call(withArguments: [app])
            return
        }

        if let window = userInfo[appObserverWindowKey] as? Window {
            call(withArguments: [window])
            return
        }
    }
}
