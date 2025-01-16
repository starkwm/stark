import Carbon

public let modifierIdentifiers = [
  "shift",
  "ctrl", "control",
  "alt", "opt", "option",
  "cmd", "command",
  "hyper",
]

public enum Modifier {
  public static func flags(for modifiers: [String]) -> UInt32 {
    let mods = Set(modifiers.map { $0.lowercased() })

    var flags = 0

    if !mods.intersection(Set(["shift"])).isEmpty {
      flags |= shiftKey
    }

    if !mods.intersection(Set(["ctrl", "control"])).isEmpty {
      flags |= controlKey
    }

    if !mods.intersection(Set(["alt", "opt", "option"])).isEmpty {
      flags |= optionKey
    }

    if !mods.intersection(Set(["cmd", "command"])).isEmpty {
      flags |= cmdKey
    }

    if mods.contains("hyper") {
      flags |= cmdKey | optionKey | shiftKey | controlKey
    }

    return UInt32(flags)
  }
}
