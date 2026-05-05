import JavaScriptCore

class Keymap: NSObject {
  private static func identifier(for key: String, modifiers: [String]) -> String {
    String(format: "%@[%@]", key, modifiers.joined(separator: "|"))
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
  private var callback: JSValue?

  init(key: String, modifiers: [String], callback: JSValue) {
    self.key = key
    self.modifiers = modifiers
    self.callback = callback

    super.init()

    shortcut = Shortcut(key: key, modifiers: modifiers)
    shortcut?.handler = call
  }

  func activate(with shortcutManager: ShortcutManager) {
    guard let shortcut else { return }
    shortcutManager.register(shortcut: shortcut)
  }

  func deactivate(with shortcutManager: ShortcutManager) {
    guard let shortcut else { return }
    shortcutManager.unregister(shortcut: shortcut)
  }

  private func call() {
    JSCallbackInvoker.call(callback, withArguments: [])
  }
}
