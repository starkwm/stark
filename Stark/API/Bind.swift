import Carbon
import JavaScriptCore

@objc protocol BindJSExport: JSExport {
    init(key: String, modifiers: [String], callback: JSValue)

    var key: String { get }
    var modifiers: [String] { get }

    func enable() -> Bool
    func disable() -> Bool

    var isEnabled: Bool { get }
}

fileprivate var bindIdentifierSequence: UInt = 0

fileprivate let starkHotKeyIdentifier = "starkHotKeyIdentifier"
fileprivate let starkHotKeyKeyDownNotification = "starkHotKeyKeyDownNotification"

open class Bind: Handler, BindJSExport, HashableJSExport {
    // swiftlint:disable:next variable_name
    fileprivate static var __once: () = {
        let callback: EventHandlerUPP = { (handler, event, data) -> OSStatus in
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

                NotificationCenter.default.post(name: Notification.Name(rawValue: starkHotKeyKeyDownNotification), object: nil, userInfo: [starkHotKeyIdentifier: UInt(identifier.id)])
            }

            return noErr
        }

        var keyDown = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &keyDown, nil, nil)
    }()

    open override var hashValue: Int { return Bind.hashForKey(key, modifiers: modifiers) }

    open var key: String = ""
    open var modifiers: [String] = []

    fileprivate var identifier: UInt = 0

    fileprivate var keyCode: UInt32 = 0
    fileprivate var modifierFlags: UInt32 = 0

    fileprivate var eventHotKeyRef: EventHotKeyRef?

    fileprivate var enabled = false

    open static func hashForKey(_ key: String, modifiers: [String]) -> Int {
        let key = String(format: "%@[%@]", key, modifiers.joined(separator: "|"))
        return key.hashValue
    }

    public required init(key: String, modifiers: [String], callback: JSValue) {
        _ = Bind.__once

        self.key = key
        self.modifiers = modifiers

        keyCode = UInt32(KeyCodeHelper.keyCodeForString(key: key))
        modifierFlags = UInt32(KeyCodeHelper.modifierFlagsForString(modifiers: modifiers))

        bindIdentifierSequence += 1
        identifier = bindIdentifierSequence

        super.init()

        manageCallback(callback)

        NotificationCenter.default.addObserver(self, selector: #selector(Bind.keyDown(notification:)), name: NSNotification.Name(rawValue: starkHotKeyKeyDownNotification), object: nil)

        _ = enable()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: starkHotKeyKeyDownNotification), object: nil)

        _ = disable()
    }

    open func enable() -> Bool {
        if enabled {
            return true
        }

        let eventHotKeyID = EventHotKeyID(signature: UTGetOSTypeFromString("STRK" as CFString), id: UInt32(identifier))

        let status = RegisterEventHotKey(keyCode, modifierFlags, eventHotKeyID, GetEventDispatcherTarget(), 0, &eventHotKeyRef)

        if status != noErr {
            return false
        }

        enabled = true

        return true
    }

    open func disable() -> Bool {
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

    open var isEnabled: Bool {
        return enabled
    }

    func keyDown(notification: Notification) {
        if let userDict = notification.userInfo {
            if identifier == userDict[starkHotKeyIdentifier] as? UInt {
                call()
            }
        }
    }
}
