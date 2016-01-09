import Carbon

public typealias HotKeyHandler = () -> ()

public class KeyKit: NSObject {
    public static let sharedInstance = KeyKit()

    public static let signature = UTGetOSTypeFromString("KKFW")

    private var eventHotKeyRef: EventHotKeyRef = nil

    private var hotkeys = [UInt32: HotKey]()

    override init() {
        var eventTypeSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetEventDispatcherTarget(),
            KeyKitCarbonEventCallbackPointer,
            1,
            &eventTypeSpec,
            nil,
            &eventHotKeyRef
        )
    }

    deinit {
        if eventHotKeyRef != nil {
            RemoveEventHandler(eventHotKeyRef)
            eventHotKeyRef = nil
        }
    }

    public func bind(key: String, modifiers: [String], handler: HotKeyHandler) -> HotKey {
        let hotkey = HotKey(key: key, modifiers: modifiers, handler: handler)
        hotkey.enable()

        hotkeys[hotkey.internalRegistrationNumber] = hotkey

        return hotkey
    }

    public func reset() {
        hotkeys.forEach { $1.disable() }
        hotkeys.removeAll()
    }

    public func handleCarbonEvent(event: EventRef) {
        if GetEventClass(event) != OSType(kEventClassKeyboard) {
            return
        }

        var hotKeyID = EventHotKeyID()

        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            sizeof(EventHotKeyID),
            nil,
            &hotKeyID
        )

        if status != noErr || hotKeyID.signature != KeyKit.signature {
            return
        }

        if let hotkey = hotkeys[hotKeyID.id] {
            dispatch_async(dispatch_get_main_queue()) {
                hotkey.handler()
            }
        }
    }
}
