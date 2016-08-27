import Carbon
import JavaScriptCore

@objc protocol BindJSExport: JSExport {
    @objc(on:::) static func on(key: String, modifiers: [String], callback: JSValue) -> Bind

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

public class Bind: Handler, BindJSExport {
    private static var setupDispatchToken: dispatch_once_t = 0

    private static var hotkeys: [Int: Bind] = [Int: Bind]()

    override public var hashValue: Int {
        get { return Bind.hashForKey(key, modifiers: modifiers) }
    }

    public var key: String = ""
    public var modifiers: [String] = []

    private var identifier: UInt = 0
    private var keyCode: UInt32 = 0
    private var modifierFlags: UInt32 = 0
    private var eventHotKeyRef: EventHotKeyRef = nil
    private var enabled = false

    private static func setup() {
        dispatch_once(&setupDispatchToken) {
            let callback: EventHandlerUPP = { (_, event, _) -> OSStatus in
                autoreleasepool {
                    var identifier = EventHotKeyID()

                    let status = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        sizeof(EventHotKeyID),
                        nil,
                        &identifier
                    )

                    if status != noErr {
                        return
                    }

                    NSNotificationCenter
                        .defaultCenter()
                        .postNotificationName(starkHotKeyKeyDownNotification, object: nil, userInfo: [starkHotKeyIdentifier: UInt(identifier.id)])

                }

                return noErr
            }

            var keyDown = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

            InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &keyDown, nil, nil)
        }
    }

    public static func reset() {
        hotkeys.forEach { $1.disable() }
        hotkeys.removeAll()
    }

    public static func hashForKey(key: String, modifiers: [String]) -> Int {
        let key = String(format: "%@[%@]", key, modifiers.joinWithSeparator("|"))
        return key.hashValue
    }

    @objc(on:::) public static func on(key: String, modifiers: [String], callback: JSValue) -> Bind {
        var hotkey = hotkeys[Bind.hashForKey(key, modifiers: modifiers)]

        if hotkey == nil {
            hotkey = Bind(key: key, modifiers: modifiers, callback: callback)
        }

        hotkeys[hotkey!.hashValue] = hotkey
        return hotkey!
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

        NSNotificationCenter
            .defaultCenter()
            .addObserver(self, selector: #selector(Bind.keyDown(_:)), name: starkHotKeyKeyDownNotification, object: nil)

        enable()
    }

    deinit {
        NSNotificationCenter
            .defaultCenter()
            .removeObserver(self, name: starkHotKeyKeyDownNotification, object: nil)
    }

    public func enable() -> Bool {
        if enabled {
            return true
        }

        let eventHotKeyID = EventHotKeyID(signature: UTGetOSTypeFromString("STRK"), id: UInt32(identifier))

        let status = RegisterEventHotKey(keyCode, modifierFlags, eventHotKeyID, GetEventDispatcherTarget(), 0, &eventHotKeyRef)

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

    public var isEnabled: Bool {
        get {
            return enabled
        }
    }

    func keyDown(notification: NSNotification) {
        if identifier == notification.userInfo?[starkHotKeyIdentifier]?.unsignedIntegerValue {
            call()
        }
    }
}
