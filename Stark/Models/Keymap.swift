import JavaScriptCore

@objc protocol KeymapJSExport: JSExport {
  static func on(_ key: String, _ modifiers: [String], _ callback: JSValue) -> Keymap
  static func off(_ id: String)

  var id: String { get }
  var key: String { get }
  var modifiers: [String] { get }
}

extension Keymap: KeymapJSExport {}

extension Keymap {
  override var description: String {
    "<Keymap id: \(id), key: \(key), modifiers: \(modifiers.joined(separator: "|"))>"
  }
}

class Keymap: NSObject {
  static var keymaps = [String: Keymap]()

  static func on(_ key: String, _ modifiers: [String], _ callback: JSValue) -> Keymap {
    let keymap = Keymap(key: key, modifiers: modifiers, callback: callback)
    keymaps[keymap.id] = keymap
    callback.context.virtualMachine.addManagedReference(keymap, withOwner: self)
    return keymap
  }

  static func off(_ id: String) {
    guard let keymap = keymaps.removeValue(forKey: id) else {
      return
    }

    keymap.callback?.value.context.virtualMachine.removeManagedReference(keymap, withOwner: self)
    ShortcutManager.unregister(shortcut: keymap.shortcut!)
    keymap.shortcut = nil
  }

  static func reset() {
    for id in keymaps.keys {
      off(id)
    }
  }

  var id: String {
    String(format: "%@[%@]", key, modifiers.joined(separator: "|"))
  }

  var key: String

  var modifiers: [String]

  private var shortcut: Shortcut?

  private var callback: JSManagedValue?

  init(key: String, modifiers: [String], callback: JSValue) {
    self.shortcut = Shortcut()

    self.key = key
    self.modifiers = modifiers

    super.init()

    self.callback = JSManagedValue(value: callback, andOwner: self)

    self.shortcut!.keyCode = Key.code(for: key)
    self.shortcut!.modifierFlags = Modifier.flags(for: modifiers)
    self.shortcut!.handler = call

    ShortcutManager.register(shortcut: shortcut!)
  }

  private func call() {
    guard let callback = callback?.value else {
      return
    }

    let context = JSContext(virtualMachine: callback.context.virtualMachine)

    context?.exceptionHandler = { _, err in
      error("javascript exception - \(String(describing: err))")
    }

    let function = JSValue(object: callback, in: context)
    function?.call(withArguments: [])
  }
}
