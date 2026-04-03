import Carbon

private let relocatableKeyCodes: [Int] = [
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

private let specialKeys: [String: (keyCode: UInt32, modifiers: Modifier)] = [
  "return": (keyCode: UInt32(kVK_Return), modifiers: []),
  "enter": (keyCode: UInt32(kVK_Return), modifiers: []),
  "tab": (keyCode: UInt32(kVK_Tab), modifiers: []),
  "space": (keyCode: UInt32(kVK_Space), modifiers: []),
  "backspace": (keyCode: UInt32(kVK_Delete), modifiers: []),
  "capslock": (keyCode: UInt32(kVK_CapsLock), modifiers: []),
  "caps": (keyCode: UInt32(kVK_CapsLock), modifiers: []),
  "escape": (keyCode: UInt32(kVK_Escape), modifiers: []),
  "esc": (keyCode: UInt32(kVK_Escape), modifiers: []),
  "backtick": (keyCode: UInt32(kVK_ANSI_Grave), modifiers: []),
  "grave": (keyCode: UInt32(kVK_ANSI_Grave), modifiers: []),
  "delete": (keyCode: UInt32(kVK_ForwardDelete), modifiers: [.fn]),
  "del": (keyCode: UInt32(kVK_ForwardDelete), modifiers: [.fn]),
  "home": (keyCode: UInt32(kVK_Home), modifiers: [.fn]),
  "end": (keyCode: UInt32(kVK_End), modifiers: [.fn]),
  "pageup": (keyCode: UInt32(kVK_PageUp), modifiers: [.fn]),
  "pagedown": (keyCode: UInt32(kVK_PageDown), modifiers: [.fn]),
  "insert": (keyCode: UInt32(kVK_Help), modifiers: [.fn]),
  "left": (keyCode: UInt32(kVK_LeftArrow), modifiers: [.fn]),
  "right": (keyCode: UInt32(kVK_RightArrow), modifiers: [.fn]),
  "up": (keyCode: UInt32(kVK_UpArrow), modifiers: [.fn]),
  "down": (keyCode: UInt32(kVK_DownArrow), modifiers: [.fn]),
  "f1": (keyCode: UInt32(kVK_F1), modifiers: [.fn]),
  "f2": (keyCode: UInt32(kVK_F2), modifiers: [.fn]),
  "f3": (keyCode: UInt32(kVK_F3), modifiers: [.fn]),
  "f4": (keyCode: UInt32(kVK_F4), modifiers: [.fn]),
  "f5": (keyCode: UInt32(kVK_F5), modifiers: [.fn]),
  "f6": (keyCode: UInt32(kVK_F6), modifiers: [.fn]),
  "f7": (keyCode: UInt32(kVK_F7), modifiers: [.fn]),
  "f8": (keyCode: UInt32(kVK_F8), modifiers: [.fn]),
  "f9": (keyCode: UInt32(kVK_F9), modifiers: [.fn]),
  "f10": (keyCode: UInt32(kVK_F10), modifiers: [.fn]),
  "f11": (keyCode: UInt32(kVK_F11), modifiers: [.fn]),
  "f12": (keyCode: UInt32(kVK_F12), modifiers: [.fn]),
  "f13": (keyCode: UInt32(kVK_F13), modifiers: [.fn]),
  "f14": (keyCode: UInt32(kVK_F14), modifiers: [.fn]),
  "f15": (keyCode: UInt32(kVK_F15), modifiers: [.fn]),
  "f16": (keyCode: UInt32(kVK_F16), modifiers: [.fn]),
  "f17": (keyCode: UInt32(kVK_F17), modifiers: [.fn]),
  "f18": (keyCode: UInt32(kVK_F18), modifiers: [.fn]),
  "f19": (keyCode: UInt32(kVK_F19), modifiers: [.fn]),
  "f20": (keyCode: UInt32(kVK_F20), modifiers: [.fn]),
  "minus": (keyCode: UInt32(kVK_ANSI_Minus), modifiers: []),
  "dash": (keyCode: UInt32(kVK_ANSI_Minus), modifiers: []),
  "equal": (keyCode: UInt32(kVK_ANSI_Equal), modifiers: []),
  "equals": (keyCode: UInt32(kVK_ANSI_Equal), modifiers: []),
  "leftbracket": (keyCode: UInt32(kVK_ANSI_LeftBracket), modifiers: []),
  "rightbracket": (keyCode: UInt32(kVK_ANSI_RightBracket), modifiers: []),
  "semicolon": (keyCode: UInt32(kVK_ANSI_Semicolon), modifiers: []),
  "quote": (keyCode: UInt32(kVK_ANSI_Quote), modifiers: []),
  "singlequote": (keyCode: UInt32(kVK_ANSI_Quote), modifiers: []),
  "backslash": (keyCode: UInt32(kVK_ANSI_Backslash), modifiers: []),
  "period": (keyCode: UInt32(kVK_ANSI_Period), modifiers: []),
  "comma": (keyCode: UInt32(kVK_ANSI_Comma), modifiers: []),
  "slash": (keyCode: UInt32(kVK_ANSI_Slash), modifiers: []),
  "forwardslash": (keyCode: UInt32(kVK_ANSI_Slash), modifiers: []),
]

enum Key {
  private static let relocatable: [String: Int] = {
    var keys = [String: Int]()

    if let data = getKeyboardLayoutData() {
      for keyCode in relocatableKeyCodes {
        if let key = getKeyString(from: data, keyCode: keyCode) {
          keys[key.lowercased()] = keyCode
        }
      }
    }
    return keys
  }()

  static func resolve(_ key: String) -> (keyCode: UInt32, modifiers: Modifier) {
    let normalizedKey = key.lowercased()

    if let specialKey = specialKeys[normalizedKey] {
      return specialKey
    }

    if let keyCode = relocatable[normalizedKey] {
      return (keyCode: UInt32(keyCode), modifiers: [])
    }

    return (keyCode: 0, modifiers: [])
  }

  private static func getKeyboardLayoutData() -> UnsafePointer<UCKeyboardLayout>? {
    let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeUnretainedValue()
    let dataRefPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)

    guard let dataRef = unsafeBitCast(dataRefPtr, to: CFData?.self) else { return nil }

    return unsafeBitCast(CFDataGetBytePtr(dataRef), to: UnsafePointer<UCKeyboardLayout>.self)
  }

  private static func getKeyString(from data: UnsafePointer<UCKeyboardLayout>, keyCode: Int)
    -> String?
  {
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

    guard length > 0 else { return nil }

    return String(utf16CodeUnits: &chars, count: length)
  }
}
