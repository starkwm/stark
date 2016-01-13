import Carbon

class KeyCodeHelper {
    private static let relocatableKeyCodes = [
        kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E,
        kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J,
        kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O,
        kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R, kVK_ANSI_S, kVK_ANSI_T,
        kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y,
        kVK_ANSI_Z,

        kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
        kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,

        kVK_ANSI_Grave,
        kVK_ANSI_Equal,
        kVK_ANSI_Minus,
        kVK_ANSI_RightBracket,
        kVK_ANSI_LeftBracket,
        kVK_ANSI_Quote,
        kVK_ANSI_Semicolon,
        kVK_ANSI_Backslash,
        kVK_ANSI_Comma,
        kVK_ANSI_Slash,
        kVK_ANSI_Period
    ]

    private static let relocatableKeys: [String: Int] = {
        var keys = [String: Int]()

        let inputSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeUnretainedValue()
        let layoutDataRefPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData)
        let layoutDataRef = unsafeBitCast(layoutDataRefPtr, CFDataRef.self)
        let layoutData = unsafeBitCast(CFDataGetBytePtr(layoutDataRef), UnsafePointer<UCKeyboardLayout>.self)

        for keyCode in relocatableKeyCodes {
            var deadKeyState: UInt32 = 0
            let maxLength = 255
            var length = 0
            var chars = [UniChar](count: maxLength, repeatedValue: 0)

            UCKeyTranslate(
                layoutData,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                maxLength,
                &length,
                &chars
            )

            if length == 0 {
                continue
            }

            let key = String(utf16CodeUnits: &chars, count: length)
            keys[key.uppercaseString] = keyCode
        }
        
        return keys
    }()

    static func keyCodeForString(key: String) -> Int {
        if let keyCode = relocatableKeys[key.uppercaseString] {
            return keyCode
        }

        switch key.uppercaseString {
        case "F1": return kVK_F1
        case "F2": return kVK_F2
        case "F3": return kVK_F3
        case "F4": return kVK_F4
        case "F5": return kVK_F5
        case "F6": return kVK_F6
        case "F7": return kVK_F7
        case "F8": return kVK_F8
        case "F9": return kVK_F9
        case "F10": return kVK_F10
        case "F11": return kVK_F11
        case "F12": return kVK_F12
        case "F13": return kVK_F13
        case "F14": return kVK_F14
        case "F15": return kVK_F15
        case "F16": return kVK_F16
        case "F17": return kVK_F17
        case "F18": return kVK_F18
        case "F19": return kVK_F19
        case "F20": return kVK_F20

        case "PAD.": return kVK_ANSI_KeypadDecimal
        case "PAD*": return kVK_ANSI_KeypadMultiply
        case "PAD+": return kVK_ANSI_KeypadPlus
        case "PAD/": return kVK_ANSI_KeypadDivide
        case "PAD-": return kVK_ANSI_KeypadMinus
        case "PAD=": return kVK_ANSI_KeypadEquals
        case "PAD0": return kVK_ANSI_Keypad0
        case "PAD1": return kVK_ANSI_Keypad1
        case "PAD2": return kVK_ANSI_Keypad2
        case "PAD3": return kVK_ANSI_Keypad3
        case "PAD4": return kVK_ANSI_Keypad4
        case "PAD5": return kVK_ANSI_Keypad5
        case "PAD6": return kVK_ANSI_Keypad6
        case "PAD7": return kVK_ANSI_Keypad7
        case "PAD8": return kVK_ANSI_Keypad8
        case "PAD9": return kVK_ANSI_Keypad9
        case "PAD_CLEAR": return kVK_ANSI_KeypadClear
        case "PAD_ENTER": return kVK_ANSI_KeypadEnter

        case "RETURN": return kVK_Return
        case "TAB": return kVK_Tab
        case "SPACE": return kVK_Space
        case "DELETE": return kVK_Delete
        case "ESCAPE": return kVK_Escape
        case "HELP": return kVK_Help
        case "HOME": return kVK_Home
        case "PAGE_UP": return kVK_PageUp
        case "PAGE_DOWN": return kVK_PageDown
        case "FORWARD_DELETE": return kVK_ForwardDelete
        case "END": return kVK_End
        case "LEFT": return kVK_LeftArrow
        case "RIGHT": return kVK_RightArrow
        case "UP": return kVK_UpArrow
        case "DOWN": return kVK_DownArrow

        default: return 0
        }
    }

    static func modifierFlagsForString(modifiers: [String]) -> Int {
        let mods = modifiers.map { $0.uppercaseString }

        var flags = 0

        if mods.contains("SHIFT") {
            flags |= shiftKey
        }

        if mods.contains("CTRL") {
            flags |= controlKey
        }

        if mods.contains("ALT") {
            flags |= optionKey
        }

        if mods.contains("CMD") {
            flags |= cmdKey
        }
        
        return flags
    }
}