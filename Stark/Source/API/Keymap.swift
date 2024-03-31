import Alicia
import Carbon
import JavaScriptCore

/// Keymap is a shortcut key combination that has a callback that is called when the shortcut is pressed.
public class Keymap: NSObject, KeymapJSExport {
  /// The shortcut registered with the Alicia library.
  private var shortcut: Shortcut

  /// The managed JavaScript value for the callback function.
  private var callback: JSManagedValue?

  /// The identifier for the keymap.
  public var id: Int {
    String(format: "%@[%@]", key, modifiers.joined(separator: "|")).hashValue
  }

  /// The key part of the keymap shortcut.
  public var key: String = ""

  /// The modifiers part of the keymap shortcut.
  public var modifiers: [String] = []

  /// Initialise a new keymap.
  public required init(key: String, modifiers: [String], callback: JSValue) {
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

  /// Unregister the shortcut when the keymap is deinitialised.
  deinit {
    Alicia.unregister(shortcut: shortcut)
  }

  /// Call the managed JavaScript callback function.
  private func call() {
    guard let callback = callback?.value else {
      return
    }

    let scope = JSContext(virtualMachine: callback.context.virtualMachine)

    if UserDefaults.standard.bool(forKey: logJavaScriptExceptionsKey) {
      scope?.exceptionHandler = { _, exception in
        LogHelper.log(message: String(format: "Error: JavaScript exception (%@)", exception!))
      }
    }

    let function = JSValue(object: callback, in: scope)
    function?.call(withArguments: [])
  }
}
