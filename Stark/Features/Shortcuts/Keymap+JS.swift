import JavaScriptCore

@objc
protocol KeymapJSExport: JSExport {
  func on(_ key: String, _ modifiers: [String], _ callback: JSValue) -> Keymap
  func off(_ id: String)
}

@objc
protocol KeymapObjectJSExport: JSExport {
  var id: String { get }
  var key: String { get }
  var modifiers: [String] { get }
}

final class KeymapBridge: NSObject, KeymapJSExport {
  private unowned let session: ConfigSession

  init(session: ConfigSession) {
    self.session = session
  }

  func on(_ key: String, _ modifiers: [String], _ callback: JSValue) -> Keymap {
    session.registerKeymap(key, modifiers: modifiers, callback: callback)
  }

  func off(_ id: String) {
    session.removeKeymap(id: id)
  }
}

extension Keymap: KeymapObjectJSExport {}
