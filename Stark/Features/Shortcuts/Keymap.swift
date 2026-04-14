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
  private var callback: JSManagedValue?

  init(key: String, modifiers: [String], callback: JSValue, callbackOwner: AnyObject) {
    self.key = key
    self.modifiers = modifiers
    shortcut = Shortcut(key: key, modifiers: modifiers)
    self.callback = JSManagedValue(value: callback, andOwner: callbackOwner)

    super.init()

    shortcut?.handler = call
    JSCallbackInvoker.addManagedReference(for: self, callback: callback, owner: callbackOwner)
  }

  deinit {
    log("keymap deinit \(self)")
  }

  func activate(with shortcutManager: ShortcutManager) {
    guard let shortcut else { return }
    shortcutManager.register(shortcut: shortcut)
  }

  func deactivate(with shortcutManager: ShortcutManager) {
    guard let shortcut else { return }
    shortcutManager.unregister(shortcut: shortcut)
  }

  func detachCallback(from owner: AnyObject) {
    JSCallbackInvoker.removeManagedReference(for: self, callback: callback, owner: owner)
  }

  private func call() {
    JSCallbackInvoker.call(callback, withArguments: [])
  }
}
