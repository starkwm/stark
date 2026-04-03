import Carbon

struct Modifier: OptionSet, Hashable {
  static let alt = Modifier(rawValue: 1 << 0)
  static let lalt = Modifier(rawValue: 1 << 1)
  static let ralt = Modifier(rawValue: 1 << 2)
  static let shift = Modifier(rawValue: 1 << 3)
  static let lshift = Modifier(rawValue: 1 << 4)
  static let rshift = Modifier(rawValue: 1 << 5)
  static let cmd = Modifier(rawValue: 1 << 6)
  static let lcmd = Modifier(rawValue: 1 << 7)
  static let rcmd = Modifier(rawValue: 1 << 8)
  static let ctrl = Modifier(rawValue: 1 << 9)
  static let lctrl = Modifier(rawValue: 1 << 10)
  static let rctrl = Modifier(rawValue: 1 << 11)
  static let fn = Modifier(rawValue: 1 << 12)

  private static let allCases: [(String, Modifier)] = [
    ("alt", .alt), ("lalt", .lalt), ("ralt", .ralt),
    ("cmd", .cmd), ("lcmd", .lcmd), ("rcmd", .rcmd),
    ("ctrl", .ctrl), ("lctrl", .lctrl), ("rctrl", .rctrl),
    ("shift", .shift), ("lshift", .lshift), ("rshift", .rshift),
    ("fn", .fn),
    ("meh", [.alt, .ctrl, .shift]),
    ("hyper", [.alt, .cmd, .ctrl, .shift]),
  ]

  private static let excludedDescriptionLiterals: Set<String> = ["meh", "hyper"]
  private static let values = Dictionary(uniqueKeysWithValues: allCases)

  let rawValue: UInt32

  static func parse(_ modifiers: [String]) -> Modifier? {
    let normalizedModifiers = Set(modifiers.map { $0.lowercased() })

    var parsedModifiers = Modifier()
    var unknownModifiers = [String]()

    for modifier in normalizedModifiers {
      if let parsedModifier = values[modifier] {
        parsedModifiers.formUnion(parsedModifier)
      } else {
        unknownModifiers.append(modifier)
      }
    }

    guard unknownModifiers.isEmpty else {
      log(
        "unknown modifier keys: \(unknownModifiers.sorted().joined(separator: ", "))",
        level: .warn
      )
      return nil
    }

    return parsedModifiers
  }

  static func from(_ eventFlags: CGEventFlags) -> Modifier {
    var result = ModifierGroup.groups.reduce(into: Modifier()) { flags, group in
      flags.formUnion(group.from(eventFlags))
    }

    if eventFlags.contains(.maskSecondaryFn) {
      result.insert(.fn)
    }

    return result
  }

  static func compare(_ expected: Modifier, _ actual: Modifier) -> Bool {
    func contains(_ flags: Modifier, _ flag: Modifier) -> Bool {
      flags.contains(flag)
    }

    func matches(_ generic: Modifier, _ left: Modifier, _ right: Modifier) -> Bool {
      contains(expected, generic)
        ? contains(actual, left) || contains(actual, right) || contains(actual, generic)
        : contains(expected, left) == contains(actual, left)
          && contains(expected, right) == contains(actual, right)
          && contains(expected, generic) == contains(actual, generic)
    }

    return ModifierGroup.groups.allSatisfy { group in
      matches(group.generic, group.left, group.right)
    } && contains(expected, .fn) == contains(actual, .fn)
  }
}

extension Modifier: CustomStringConvertible {
  var description: String {
    guard !isEmpty else { return "<Modifier none>" }

    let flags = Self.allCases.compactMap { name, flag in
      contains(flag) && !Self.excludedDescriptionLiterals.contains(name) ? name : nil
    }

    return "<Modifier \(flags.joined(separator: "|"))>"
  }
}
