import Carbon

enum Modifier {
  private static let keyFlags: [String: Int] = [
    "shift": shiftKey,
    "ctrl": controlKey, "control": controlKey,
    "alt": optionKey, "opt": optionKey, "option": optionKey,
    "cmd": cmdKey, "command": cmdKey,
    "meh": optionKey | shiftKey | controlKey,
    "hyper": cmdKey | optionKey | shiftKey | controlKey,
  ]

  static func flags(for modifiers: [String]) -> UInt32 {
    let mods = Set(modifiers.map { $0.lowercased() })

    var flags = 0

    for mod in mods {
      if let keyFlag = keyFlags[mod] {
        flags |= keyFlag
      }
    }

    return UInt32(flags)
  }
}
