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

class Keymap: NSObject {
  var id: Int {
    String(format: "%@[%@]", key, modifiers.joined(separator: "|")).hashValue
  }

  var key: String = ""

  var modifiers: [String] = []

  var shortcut: Shortcut

  var callback: JSManagedValue?

  required init(key: String, modifiers: [String], callback: JSValue) {
    shortcut = Shortcut()

    self.key = key
    self.modifiers = modifiers

    super.init()

    self.callback = JSManagedValue(value: callback, andOwner: self)

    shortcut.keyCode = Key.code(for: key)
    shortcut.modifierFlags = Modifier.flags(for: modifiers)
    shortcut.handler = call

    Alicia.register(shortcut: shortcut)
  }

  deinit {
    Alicia.unregister(shortcut: shortcut)
  }

  func call() {
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
