import Carbon
import JavaScriptCore

@objc protocol HotKeyJSExport: JSExport {
    var key: String { get }
    var modifiers: [String] { get }

    func enable() -> Bool
    func disable() -> Bool
}

let StarkHotKeySignature = UTGetOSTypeFromString("STRK")
let StarkHotKeyIdentifier = "StarkHotKeyIdentifier"
let StarkHotKeyKeyDownNotification = "StarkHotKeyKeyDownNotification"

public class HotKey: NSObject, HotKeyJSExport {
    private static var dispatchToken: dispatch_once_t = 0

    private static var indentifierSequence: UInt = 0

    public var key: String
    public var modifiers: [String]

    private var enabled = false

    private var eventHotKeyRef: EventHotKeyRef = nil

    private var identifier: UInt

    private var keyCode: UInt32
    private var modifierFlags: UInt32

    private var handler: () -> ()

    static func setup() {
        dispatch_once(&dispatchToken) {
            var keyDown = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

            InstallEventHandler(
                GetEventDispatcherTarget(),
                StarkCarbonEventCallbackPointer,
                1,
                &keyDown,
                nil,
                nil
            )
        }
    }

    static func handleEvent(event: EventRef) {
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

        NSNotificationCenter.defaultCenter().postNotificationName(
            StarkHotKeyKeyDownNotification,
            object: nil,
            userInfo: [StarkHotKeyIdentifier: UInt(identifier.id)]
        )
    }

    init(key: String, modifiers: [String], handler: () -> ()) {
        HotKey.setup()

        self.key = key
        self.modifiers = modifiers

        self.keyCode = UInt32(KeyCodeHelper.keyCodeForString(self.key))
        self.modifierFlags = UInt32(KeyCodeHelper.modifierFlagsForString(self.modifiers))

        self.handler = handler

        self.identifier = ++HotKey.indentifierSequence

        super.init()

        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "keyDown:",
            name: StarkHotKeyKeyDownNotification,
            object: nil
        )

        enable()
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(
            self,
            name: StarkHotKeyKeyDownNotification,
            object: nil
        )
    }

    public func enable() -> Bool {
        if enabled {
            return true
        }

        let identifier = EventHotKeyID(
            signature: StarkHotKeySignature,
            id: UInt32(self.identifier)
        )

        let status = RegisterEventHotKey(
            keyCode, modifierFlags,
            identifier,
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

    func keyDown(notification: NSNotification) {
        if let identifier = notification.userInfo?[StarkHotKeyIdentifier]?.unsignedIntegerValue {
            if self.identifier == identifier {
                handler()
            }
        }
    }
}