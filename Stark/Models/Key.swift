import Carbon

private let relocatableKeyCodes = [
  kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E,
  kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J,
  kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O,
  kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R, kVK_ANSI_S, kVK_ANSI_T,
  kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y,
  kVK_ANSI_Z,

  kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
  kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,

  kVK_ANSI_Period,
  kVK_ANSI_Quote,
  kVK_ANSI_RightBracket,
  kVK_ANSI_Semicolon,
  kVK_ANSI_Slash,
  kVK_ANSI_Backslash,
  kVK_ANSI_Comma,
  kVK_ANSI_Equal,
  kVK_ANSI_Grave,
  kVK_ANSI_LeftBracket,
  kVK_ANSI_Minus,
]

public let keyToCode = [
  "space": kVK_Space,
  "tab": kVK_Tab,
  "return": kVK_Return,
  "enter": kVK_Return,

  "capslock": kVK_CapsLock,

  "pageup": kVK_PageUp,
  "pagedown": kVK_PageDown,
  "home": kVK_Home,
  "end": kVK_End,
  "up": kVK_UpArrow,
  "right": kVK_RightArrow,
  "down": kVK_DownArrow,
  "left": kVK_LeftArrow,

  "f1": kVK_F1,
  "f2": kVK_F2,
  "f3": kVK_F3,
  "f4": kVK_F4,
  "f5": kVK_F5,
  "f6": kVK_F6,
  "f7": kVK_F7,
  "f8": kVK_F8,
  "f9": kVK_F9,
  "f10": kVK_F10,
  "f11": kVK_F11,
  "f12": kVK_F12,
  "f13": kVK_F13,
  "f14": kVK_F14,
  "f15": kVK_F15,
  "f16": kVK_F16,
  "f17": kVK_F17,
  "f18": kVK_F18,
  "f19": kVK_F19,
  "f20": kVK_F20,

  "escape": kVK_Escape,
  "esc": kVK_Escape,
  "delete": kVK_Delete,

  "grave": kVK_ANSI_Grave,
  "backtick": kVK_ANSI_Grave,
  "minus": kVK_ANSI_Minus,
  "dash": kVK_ANSI_Minus,
  "equal": kVK_ANSI_Equal,
  "equals": kVK_ANSI_Equal,
  "leftbracket": kVK_ANSI_LeftBracket,
  "rightbracket": kVK_ANSI_RightBracket,
  "semicolon": kVK_ANSI_Semicolon,
  "quote": kVK_ANSI_Quote,
  "singlequote": kVK_ANSI_Quote,
  "backslash": kVK_ANSI_Backslash,
  "period": kVK_ANSI_Period,
  "comma": kVK_ANSI_Comma,
  "slash": kVK_ANSI_Slash,
  "forwardslash": kVK_ANSI_Slash,
]

public enum Key {
  private static let relocatable: [String: Int] = {
    var keys = [String: Int]()

    let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeUnretainedValue()
    let dataRefPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    let dataRef = unsafeBitCast(dataRefPtr, to: CFData.self)
    let data = unsafeBitCast(CFDataGetBytePtr(dataRef), to: UnsafePointer<UCKeyboardLayout>.self)

    for keyCode in relocatableKeyCodes {
      var deadKeyState: UInt32 = 0
      let maxLength = 255
      var length = 0
      var chars = [UniChar](repeating: 0, count: maxLength)

      UCKeyTranslate(
        data,
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
      keys[key.lowercased()] = keyCode
    }

    return keys
  }()

  public static func code(for key: String) -> UInt32 {
    if let keyCode = relocatable[key.lowercased()] {
      return UInt32(keyCode)
    }

    return UInt32(keyToCode[key.lowercased()] ?? 0)
  }
}
