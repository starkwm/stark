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

private var bindIdentifierSequence: UInt = 0

private let starkHotKeyIdentifier = "starkHotKeyIdentifier"
private let starkHotKeyKeyDownNotification = "starkHotKeyKeyDownNotification"

open class Bind: Handler, BindJSExport, HashableJSExport {
    private static var __once: () = {
            let callback: EventHandlerUPP = { (_, event, _) -> OSStatus in
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

                    NotificationCenter.default
                        .post(name: Notification.Name(rawValue: starkHotKeyKeyDownNotification), object: nil, userInfo: [starkHotKeyIdentifier: UInt(identifier.id)])

                }

                return noErr
            }

            var keyDown = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

            InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &keyDown, nil, nil)
        }()
    fileprivate static var setupDispatchToken: Int = 0

    fileprivate static var hotkeys: [Int: Bind] = [Int: Bind]()

    override open var hashValue: Int {
        get { return Bind.hashForKey(key, modifiers: modifiers) }
    }

    open var key: String = ""
    open var modifiers: [String] = []

    fileprivate var identifier: UInt = 0
    fileprivate var keyCode: UInt32 = 0
    fileprivate var modifierFlags: UInt32 = 0
    fileprivate var eventHotKeyRef: EventHotKeyRef? = nil
    fileprivate var enabled = false

    fileprivate static func setup() {
        _ = Bind.__once
    }

    open static func reset() {
        hotkeys.forEach { _ = $1.disable() }
        hotkeys.removeAll()
    }

    open static func hashForKey(_ key: String, modifiers: [String]) -> Int {
        let key = String(format: "%@[%@]", key, modifiers.joined(separator: "|"))
        return key.hashValue
    }

    public required init(key: String, modifiers: [String], callback: JSValue) {
        Bind.setup()

        self.key = key
        self.modifiers = modifiers

        keyCode = UInt32(KeyCodeHelper.keyCodeForString(key))
        modifierFlags = UInt32(KeyCodeHelper.modifierFlagsForString(modifiers))

        bindIdentifierSequence += 1
        identifier = bindIdentifierSequence

        super.init()

        manageCallback(callback)

        NotificationCenter.default
            .addObserver(self, selector: #selector(Bind.keyDown(notification:)), name: NSNotification.Name(rawValue: starkHotKeyKeyDownNotification), object: nil)

        _ = enable()
    }

    deinit {
        NotificationCenter.default
            .removeObserver(self, name: NSNotification.Name(rawValue: starkHotKeyKeyDownNotification), object: nil)
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
        get {
            return enabled
        }
    }

    func keyDown(notification: Notification) {
        if let userDict = notification.userInfo {
            if identifier == userDict[starkHotKeyIdentifier] as? UInt {
                call()
            }
        }
    }
}
