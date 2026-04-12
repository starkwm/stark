import JavaScriptCore

@objc protocol KeymapJSExport: JSExport {

  static func on(_ key: String, _ modifiers: [String], _ callback: JSValue) -> Keymap

  static func off(_ id: String)


  var id: String { get }

  var key: String { get }

  var modifiers: [String] { get }
}

class Keymap: NSObject, KeymapJSExport {
  private static let registry = KeymapRegistry()

  private static func identifier(for key: String, modifiers: [String]) -> String {
    String(format: "%@[%@]", key, modifiers.joined(separator: "|"))
  }

  static func configureShortcutManager(_ manager: ShortcutManager) {
    registry.configure(shortcutManager: manager)
  }

  static func beginRecording() {
    registry.beginRecording()
  }

  static func commitRecording() {
    guard let transition = registry.commitRecording() else { return }

    for keymap in transition.previousActive.values {
      removeManagedReference(for: keymap)
      if let shortcut = keymap.shortcut {
        registry.shortcutManager.unregister(shortcut: shortcut)
      }
    }

    for keymap in transition.nextActive.values {
      keymap.activate()
    }
  }

  static func discardRecording() {
    guard let recordingKeymaps = registry.discardRecording() else { return }

    for keymap in recordingKeymaps.values {
      removeManagedReference(for: keymap)
    }
  }

  static func on(_ key: String, _ modifiers: [String], _ callback: JSValue) -> Keymap {
    let keymap = Keymap(key: key, modifiers: modifiers, callback: callback)

    let result = registry.insert(keymap)

    if let previous = result.previous {
      removeManagedReference(for: previous)

      if !result.isRecording {
        if let shortcut = previous.shortcut {
          registry.shortcutManager.unregister(shortcut: shortcut)
        }
      }
    }

    JSCallbackInvoker.addManagedReference(for: keymap, callback: callback, owner: self)

    if !result.isRecording {
      keymap.activate()
    }

    return keymap
  }

  static func off(_ id: String) {
    let result = registry.remove(id: id)

    guard let keymap = result.keymap else { return }

    removeManagedReference(for: keymap)

    if !result.isRecording {
      if let shortcut = keymap.shortcut {
        registry.shortcutManager.unregister(shortcut: shortcut)
      }
    }
  }

  static func reset() {
    let result = registry.reset()

    for keymap in result.removed {
      removeManagedReference(for: keymap)

      if !result.isRecording {
        if let shortcut = keymap.shortcut {
          registry.shortcutManager.unregister(shortcut: shortcut)
        }
      }
    }
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

  private var shortcut: Shortcut?
  private var callback: JSManagedValue?

  init(key: String, modifiers: [String], callback: JSValue) {
    self.key = key
    self.modifiers = modifiers
    shortcut = Shortcut(key: key, modifiers: modifiers)

    super.init()

    self.callback = JSManagedValue(value: callback, andOwner: self)
    shortcut?.handler = call
  }

  deinit {
    log("keymap deinit \(self)")
  }

  func activate() {
    guard let shortcut else { return }
    Self.registry.shortcutManager.register(shortcut: shortcut)
  }

  private func call() {
    JSCallbackInvoker.call(callback, withArguments: [])
  }
}
