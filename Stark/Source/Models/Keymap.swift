import Alicia
import JavaScriptCore
import OSLog

@objc protocol KeymapJSExport: JSExport {
  var id: Int { get }

  var key: String { get }
  var modifiers: [String] { get }

  init(key: String, modifiers: [String], callback: JSValue)
}

extension Keymap: KeymapJSExport {}

extension Keymap {
  override var description: String {
    "<Keymap key: \(key), modifiers: \(modifiers.joined(separator: "|"))>"
  }
}

class Keymap: NSObject {
  var id: Int {
    String(format: "%@[%@]", key, modifiers.joined(separator: "|")).hashValue
  }

  var key: String

  var modifiers: [String]

  private var shortcut: Shortcut

  private var callback: JSManagedValue?

  required init(key: String, modifiers: [String], callback: JSValue) {
    self.shortcut = Shortcut()

    self.key = key
    self.modifiers = modifiers

    super.init()

    self.callback = JSManagedValue(value: callback, andOwner: self)

    self.shortcut.keyCode = Key.code(for: key)
    self.shortcut.modifierFlags = Modifier.flags(for: modifiers)
    self.shortcut.handler = call

    Alicia.register(shortcut: shortcut)
  }

  deinit {
    Alicia.unregister(shortcut: shortcut)
  }

  private func call() {
    guard let callback = callback?.value else {
      return
    }

    let context = JSContext(virtualMachine: callback.context.virtualMachine)

    context?.exceptionHandler = { _, err in
      Logger.javascript.error("\(err)")
    }

    let function = JSValue(object: callback, in: context)
    function?.call(withArguments: [])
  }
}
