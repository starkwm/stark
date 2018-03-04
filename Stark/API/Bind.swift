//
//  Bind.swift
//  Stark
//
//  Created by Tom Bell on 22/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import Carbon
import JavaScriptCore

private let starkHotKeyIdentifier = "starkHotKeyIdentifier"
private let starkHotKeyKeyDownNotification = "starkHotKeyKeyDownNotification"

private var bindIdentifierSequence: UInt = 0

public class Bind: Handler, BindJSExport, HashableJSExport {
    private static var once: () = {
        let callback: EventHandlerUPP = { _, event, _ -> OSStatus in
            autoreleasepool {
                var identifier = EventHotKeyID()

                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )

                if status != noErr {
                    return
                }

                NotificationCenter.default.post(name: Notification.Name(rawValue: starkHotKeyKeyDownNotification),
                                                object: nil,
                                                userInfo: [starkHotKeyIdentifier: UInt(identifier.id)])
            }

            return noErr
        }

        var keyDown = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &keyDown, nil, nil)
    }()

    public required init(key: String, modifiers: [String], callback: JSValue) {
        _ = Bind.once

        self.key = key
        self.modifiers = modifiers

        keyCode = UInt32(KeyCodeHelper.keyCode(for: key))
        modifierFlags = UInt32(KeyCodeHelper.modifierFlags(for: modifiers))

        bindIdentifierSequence += 1
        identifier = bindIdentifierSequence

        super.init()

        manageCallback(callback)

        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(Bind.keyDown(notification:)),
                         name: NSNotification.Name(rawValue: starkHotKeyKeyDownNotification),
                         object: nil)

        _ = enable()
    }

    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name(rawValue: starkHotKeyKeyDownNotification),
                                                  object: nil)

        _ = disable()
    }

    private var identifier: UInt

    private var keyCode: UInt32

    private var modifierFlags: UInt32

    private var eventHotKeyRef: EventHotKeyRef?

    private var enabled = false

    public override var hashValue: Int {
        return String(format: "%@[%@]", key, modifiers.joined(separator: "|")).hashValue
    }

    public var key: String = ""

    public var modifiers: [String] = []

    public var isEnabled: Bool { return enabled }

    public func enable() -> Bool {
        if enabled {
            return true
        }

        let eventHotKeyID = EventHotKeyID(signature: UTGetOSTypeFromString("STRK" as CFString), id: UInt32(identifier))

        let status = RegisterEventHotKey(keyCode,
                                         modifierFlags,
                                         eventHotKeyID,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &eventHotKeyRef)

        if status != noErr {
            return false
        }

        enabled = true

        return true
    }

    public func disable() -> Bool {
        if !enabled {
            return true
        }

        let status = UnregisterEventHotKey(eventHotKeyRef)

        if status != noErr {
            return false
        }

        eventHotKeyRef = nil
        enabled = false

        return true
    }

    @objc
    func keyDown(notification: Notification) {
        if let userDict = notification.userInfo {
            if identifier == userDict[starkHotKeyIdentifier] as? UInt {
                call()
            }
        }
    }
}
