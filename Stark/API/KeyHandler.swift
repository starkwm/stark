import Carbon
import JavaScriptCore

@objc protocol KeyHandlerJSExport: JSExport {
    var key: String { get }
    var modifiers: [String] { get }

    func enable() -> Bool
    func disable() -> Bool

    func isEnabled() -> Bool
}

private let StarkHotKeySignature = UTGetOSTypeFromString("STRK")
private var KeyHandlerIdentifierSequence: UInt = 0

private let StarkHotKeyIdentifier = "StarkHotKeyIdentifier"
private let StarkHotKeyKeyDownNotification = "StarkHotKeyKeyDownNotification"

public class KeyHandler: Handler {
    private static var setupDispatchToken: dispatch_once_t = 0

    public var key: String = ""
    public var modifiers: [String] = []

    override public var hashValue: Int {
        get { return KeyHandler.hashForKey(key, modifiers: modifiers) }
    }

    private var identifier: UInt = 0
    private var keyCode: UInt32 = 0
    private var modifierFlags: UInt32 = 0
    private var eventHotKeyRef: EventHotKeyRef = nil
    private var enabled = false

    private static func setup() {
        dispatch_once(&setupDispatchToken) {
            var keyDown = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

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
                        .postNotificationName(StarkHotKeyKeyDownNotification, object: nil, userInfo: [StarkHotKeyIdentifier: UInt(identifier.id)])

                }

                return noErr
            }

            InstallEventHandler(
                GetEventDispatcherTarget(),
                callback,
                1,
                &keyDown,
                nil,
                nil
            )
        }
    }

    public static func hashForKey(key: String, modifiers: [String]) -> Int {
        var hash = key.hashValue
        modifiers.forEach { hash += $0.hashValue }
        return hash
    }

    init(key: String, modifiers: [String]) {
        KeyHandler.setup()

        self.key = key
        self.modifiers = modifiers
        self.keyCode = UInt32(KeyCodeHelper.keyCodeForString(key))
        self.modifierFlags = UInt32(KeyCodeHelper.modifierFlagsForString(modifiers))

        self.identifier = ++KeyHandlerIdentifierSequence

        super.init()

        NSNotificationCenter
            .defaultCenter()
            .addObserver(self, selector: #selector(KeyHandler.keyDown(_:)), name: StarkHotKeyKeyDownNotification, object: nil)

        enable()
    }

    deinit {
        NSNotificationCenter
            .defaultCenter()
            .removeObserver(self, name: StarkHotKeyKeyDownNotification, object: nil)
    }

    public func enable() -> Bool {
        if enabled {
            return true
        }

        let identifier = EventHotKeyID(signature: StarkHotKeySignature, id: UInt32(self.identifier))

        let status = RegisterEventHotKey(keyCode, modifierFlags, identifier, GetEventDispatcherTarget(), 0, &eventHotKeyRef)

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

    public func isEnabled() -> Bool {
        return enabled
    }

    func keyDown(notification: NSNotification) {
        if self.identifier == notification.userInfo?[StarkHotKeyIdentifier]?.unsignedIntegerValue {
            call()
        }
    }
}