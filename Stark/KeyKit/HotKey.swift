import Carbon

public class HotKey: NSObject {
    private static var internalCarbonID: UInt32 = 0

    private var enabled = false

    private var eventHotKeyRef: EventHotKeyRef = nil

    public var internalRegistrationNumber: UInt32 = 0

    public var key: String
    public var modifiers: [String]

    public var handler: HotKeyHandler

    init(key: String, modifiers: [String], handler: HotKeyHandler) {
        self.key = key
        self.modifiers = modifiers
        self.handler = handler

        internalRegistrationNumber = ++HotKey.internalCarbonID
    }

    public func enable() -> Bool {
        if enabled {
            return true
        }

        let key = KeyCodeHelper.keyCodeForString(self.key)
        let modifiers = KeyCodeHelper.modifierFlagsForString(self.modifiers)

        let eventHotKeyID = EventHotKeyID(signature: KeyKit.signature, id: internalRegistrationNumber)

        let status = RegisterEventHotKey(
            UInt32(key),
            UInt32(modifiers),
            eventHotKeyID,
            GetEventDispatcherTarget(),
            0,
            &eventHotKeyRef
        )

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
}
