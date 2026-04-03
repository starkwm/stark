import JavaScriptCore

/// Protocol exposing keyboard shortcut functionality to JavaScript.
/// Allows binding keyboard combinations to JavaScript callbacks.
@objc protocol KeymapJSExport: JSExport {
  // MARK: - Keymap Management

  /// Registers a keyboard shortcut with a callback.
  /// - Parameters:
  ///   - key: The key name (e.g., "return", "space", "a")
  ///   - modifiers: Array of modifier keys (e.g., ["cmd"], ["cmd", "shift"])
  ///   - callback: JavaScript function to execute when shortcut is pressed
  /// - Returns: The created keymap instance
  static func on(_ key: String, _ modifiers: [String], _ callback: JSValue) -> Keymap

  /// Unregisters a keyboard shortcut by its ID.
  /// - Parameter id: The keymap ID to unregister
  static func off(_ id: String)

  // MARK: - Properties

  /// Unique identifier for this keymap (format: "key[modifier1|modifier2]").
  var id: String { get }

  /// The key associated with this shortcut.
  var key: String { get }

  /// The modifier keys associated with this shortcut.
  var modifiers: [String] { get }
}

class Keymap: NSObject, KeymapJSExport {
  private static let keymaps = StagedStorage<[String: Keymap]>(
    active: [:],
    queueLabel: "dev.tombell.stark.keymaps",
    makeEmptyStorage: { [:] }
  )

  private static func identifier(for key: String, modifiers: [String]) -> String {
    String(format: "%@[%@]", key, modifiers.joined(separator: "|"))
  }

  /// Starts staging keymap mutations so config reloads can commit atomically.
  static func beginRecording() {
    keymaps.beginRecording()
  }

  /// Swaps staged keymaps into the active set and re-registers hotkeys to match.
  static func commitRecording() {
    guard let transition = keymaps.commit() else { return }

    for keymap in transition.previousActive.values {
      removeManagedReference(for: keymap)
      ShortcutManager.unregister(shortcut: keymap.shortcut)
    }

    for keymap in transition.nextActive.values {
      keymap.activate()
    }
  }

  /// Drops staged keymaps without disturbing the currently active registrations.
  static func discardRecording() {
    guard let recordingKeymaps = keymaps.discard() else { return }

    for keymap in recordingKeymaps.values {
      removeManagedReference(for: keymap)
    }
  }

  /// Registers a keymap immediately or stages it during a config reload.
  static func on(_ key: String, _ modifiers: [String], _ callback: JSValue) -> Keymap {
    let keymap = Keymap(key: key, modifiers: modifiers, callback: callback)

    let result = keymaps.mutate { keymaps, recordingKeymaps in
      if recordingKeymaps != nil {
        let previous = recordingKeymaps?.updateValue(keymap, forKey: keymap.id)
        return (previous, true)
      }

      let previous = keymaps.updateValue(keymap, forKey: keymap.id)
      return (previous, false)
    }

    if let previous = result.0 {
      removeManagedReference(for: previous)

      if !result.1 {
        ShortcutManager.unregister(shortcut: previous.shortcut)
      }
    }

    JSCallbackInvoker.addManagedReference(for: keymap, callback: callback, owner: self)

    if !result.1 {
      keymap.activate()
    }

    return keymap
  }

  /// Removes a keymap from either staged or active storage, unregistering it if needed.
  static func off(_ id: String) {
    let result = keymaps.mutate { keymaps, recordingKeymaps in
      if recordingKeymaps != nil {
        let keymap = recordingKeymaps?.removeValue(forKey: id)
        return (keymap, true)
      }

      let keymap = keymaps.removeValue(forKey: id)
      return (keymap, false)
    }

    guard let keymap = result.0 else { return }

    removeManagedReference(for: keymap)

    if !result.1 {
      ShortcutManager.unregister(shortcut: keymap.shortcut)
    }
  }

  /// Clears every registered keymap from the current storage mode.
  static func reset() {
    let result = keymaps.mutate { keymaps, recordingKeymaps in
      if recordingKeymaps != nil {
        let removed = recordingKeymaps.map { Array($0.values) } ?? []
        recordingKeymaps?.removeAll()
        return (removed, true)
      }

      let removed = Array(keymaps.values)
      keymaps.removeAll()
      return (removed, false)
    }

    for keymap in result.0 {
      removeManagedReference(for: keymap)

      if !result.1 {
        ShortcutManager.unregister(shortcut: keymap.shortcut)
      }
    }
  }

  static var activeIDsForTesting: [String] {
    keymaps.withActive { $0.keys.sorted() }
  }

  static var recordingIDsForTesting: [String] {
    keymaps.withRecording { $0?.keys.sorted() ?? [] }
  }

  static func resetForTesting() {
    if keymaps.withRecording({ $0 != nil }) {
      discardRecording()
    }

    reset()
  }

  private static func removeManagedReference(for keymap: Keymap) {
    JSCallbackInvoker.removeManagedReference(for: keymap, callback: keymap.callback, owner: self)
  }

  override var description: String {
    "<Keymap id: \(id), key: \(key), modifiers: \(modifiers.joined(separator: "|"))>"
  }

  var id: String {
    Self.identifier(for: key, modifiers: modifiers)
  }

  var key: String
  var modifiers: [String]

  private var shortcut: Shortcut
  private var callback: JSManagedValue?

  init(key: String, modifiers: [String], callback: JSValue) {
    self.key = key
    self.modifiers = modifiers

    shortcut = Shortcut()
    shortcut.keyCode = Key.code(for: key)
    shortcut.modifierFlags = Modifier.flags(for: modifiers)

    super.init()

    self.callback = JSManagedValue(value: callback, andOwner: self)
    shortcut.handler = call
  }

  deinit {
    log("keymap deinit \(self)")
  }

  /// Registers the underlying Carbon hotkey for this keymap.
  func activate() {
    ShortcutManager.register(shortcut: shortcut)
  }

  /// Invokes the JavaScript callback bound to this keymap.
  private func call() {
    JSCallbackInvoker.call(callback, withArguments: [])
  }
}
