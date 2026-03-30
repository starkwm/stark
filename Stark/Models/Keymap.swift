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
  private static var keymaps = [String: Keymap]()
  private static var recordingKeymaps: [String: Keymap]?

  private static func identifier(for key: String, modifiers: [String]) -> String {
    String(format: "%@[%@]", key, modifiers.joined(separator: "|"))
  }

  static func beginRecording() {
    recordingKeymaps = [:]
  }

  static func commitRecording() {
    guard let recordingKeymaps else { return }

    for keymap in keymaps.values {
      removeManagedReference(for: keymap)
    }

    keymaps = recordingKeymaps
    Self.recordingKeymaps = nil

    for keymap in keymaps.values {
      keymap.activate()
    }
  }

  static func discardRecording() {
    guard let recordingKeymaps else { return }

    for keymap in recordingKeymaps.values {
      removeManagedReference(for: keymap)
    }

    Self.recordingKeymaps = nil
  }

  static func on(_ key: String, _ modifiers: [String], _ callback: JSValue) -> Keymap {
    if recordingKeymaps == nil {
      let id = identifier(for: key, modifiers: modifiers)

      if keymaps[id] != nil {
        off(id)
      }
    }

    let keymap = Keymap(
      key: key,
      modifiers: modifiers,
      callback: callback,
      activateShortcut: recordingKeymaps == nil
    )

    callback.context.virtualMachine.addManagedReference(keymap, withOwner: self)

    if var recordingKeymaps {
      if let previous = recordingKeymaps[keymap.id] {
        removeManagedReference(for: previous)
      }

      recordingKeymaps[keymap.id] = keymap
      Self.recordingKeymaps = recordingKeymaps
      return keymap
    }

    keymaps[keymap.id] = keymap

    return keymap
  }

  static func off(_ id: String) {
    if var recordingKeymaps {
      guard let keymap = recordingKeymaps.removeValue(forKey: id) else { return }

      removeManagedReference(for: keymap)
      Self.recordingKeymaps = recordingKeymaps
      return
    }

    guard let keymap = keymaps.removeValue(forKey: id) else { return }

    removeManagedReference(for: keymap)
    ShortcutManager.unregister(shortcut: keymap.shortcut)
  }

  static func reset() {
    if let recordingKeymaps {
      for id in recordingKeymaps.keys {
        off(id)
      }
      return
    }

    for id in keymaps.keys {
      off(id)
    }
  }

  private static func removeManagedReference(for keymap: Keymap) {
    guard let callback = keymap.callback?.value else { return }

    callback.context.virtualMachine.removeManagedReference(keymap, withOwner: self)
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

  init(key: String, modifiers: [String], callback: JSValue, activateShortcut: Bool) {
    self.key = key
    self.modifiers = modifiers

    shortcut = Shortcut()
    shortcut.keyCode = Key.code(for: key)
    shortcut.modifierFlags = Modifier.flags(for: modifiers)

    super.init()

    self.callback = JSManagedValue(value: callback, andOwner: self)
    shortcut.handler = call

    if activateShortcut {
      activate()
    }
  }

  deinit {
    log("keymap deinit \(self)")
  }

  func activate() {
    ShortcutManager.register(shortcut: shortcut)
  }

  private func call() {
    guard let callback = callback?.value else { return }

    guard let context = JSContext(virtualMachine: callback.context.virtualMachine) else { return }

    context.exceptionHandler = { _, err in
      log("unhandled javascript exception - \(String(describing: err))", level: .error)
    }

    let function = JSValue(object: callback, in: context)
    function?.call(withArguments: [])
  }
}
