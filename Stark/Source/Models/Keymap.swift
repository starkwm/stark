import Alicia
import JavaScriptCore

/// The protocol for the exported attributes of Keymap.
@objc protocol KeymapJSExport: JSExport {
  var id: Int { get }

  var key: String { get }
  var modifiers: [String] { get }

  init(key: String, modifiers: [String], callback: JSValue)
}

extension Keymap: KeymapJSExport {}

/// Keymap is a shortcut key combination that has a callback that is called when the shortcut is pressed.
public class Keymap: NSObject {
  /// The identifier for the keymap.
  public var id: Int {
    String(format: "%@[%@]", key, modifiers.joined(separator: "|")).hashValue
  }

  /// The key part of the keymap shortcut.
  public var key: String = ""

  /// The modifiers part of the keymap shortcut.
  public var modifiers: [String] = []

  /// The shortcut registered with the Alicia library.
  private var shortcut: Shortcut

  /// The managed JavaScript value for the callback function.
  private var callback: JSManagedValue?

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

    let context = JSContext(virtualMachine: callback.context.virtualMachine)

    if UserDefaults.standard.bool(forKey: logJavaScriptExceptionsKey) {
      context?.exceptionHandler = { _, err in
        LogHelper.log(message: "\(err!)")
      }
    }

    let function = JSValue(object: callback, in: context)
    function?.call(withArguments: [])
  }
}
