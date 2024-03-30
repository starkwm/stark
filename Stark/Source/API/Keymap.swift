import Alicia
import Carbon
import JavaScriptCore

public class Keymap: Handler, KeymapJSExport {
  public required init(key: String, modifiers: [String], callback: JSValue) {
    shortcut = Shortcut()

    self.key = key
    self.modifiers = modifiers

    super.init()

    manageCallback(callback)

    shortcut.keyCode = Key.code(for: key)
    shortcut.modifierFlags = Modifier.flags(for: modifiers)
    shortcut.handler = call

    Alicia.register(shortcut: shortcut)
  }

  deinit {
    Alicia.unregister(shortcut: shortcut)
  }

  private var shortcut: Shortcut

  public var id: Int {
    String(format: "%@[%@]", key, modifiers.joined(separator: "|")).hashValue
  }

  public var key: String = ""
  public var modifiers: [String] = []
}
