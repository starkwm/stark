import Foundation

struct Shortcut {
  let identifier: UUID
  let keyCode: UInt32
  let modifiers: Modifier

  var handler: (() -> Void)?

  init(
    identifier: UUID = UUID(),
    keyCode: UInt32,
    modifiers: Modifier,
    handler: (() -> Void)? = nil
  ) {
    self.identifier = identifier
    self.keyCode = keyCode
    self.modifiers = modifiers
    self.handler = handler
  }

  init?(identifier: UUID = UUID(), key: String, modifiers: [String]) {
    let resolvedKey = Key.resolve(key)
    guard resolvedKey.keyCode != 0 else { return nil }

    if let parsedModifiers = Modifier.parse(modifiers) {
      self.init(
        identifier: identifier,
        keyCode: resolvedKey.keyCode,
        modifiers: parsedModifiers.union(resolvedKey.modifiers)
      )
      return
    }

    guard !resolvedKey.modifiers.isEmpty else { return nil }

    self.init(
      identifier: identifier,
      keyCode: resolvedKey.keyCode,
      modifiers: resolvedKey.modifiers
    )
  }
}
