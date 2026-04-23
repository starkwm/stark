import JavaScriptCore
import Testing

@testable import Stark

@Suite
struct KeymapTests {
  @Test
  func createsStableIdentifiers() throws {
    let session = ConfigSession()

    let keymap = session.keymapBridge.on(
      "return",
      ["cmd", "shift"],
      try callback()
    )

    #expect(keymap.id == "return[cmd|shift]")
  }

  @Test
  func preservesRawSidedModifierIdentifiers() throws {
    let session = ConfigSession()

    let keymap = session.keymapBridge.on(
      "return",
      ["lcmd", "shift"],
      try callback()
    )

    #expect(keymap.id == "return[lcmd|shift]")
  }

  @Test
  func specialKeysKeepRawIdentifiers() throws {
    let session = ConfigSession()

    let keymap = session.keymapBridge.on(
      "left",
      ["cmd"],
      try callback()
    )

    #expect(keymap.id == "left[cmd]")
  }

  private func callback() throws -> JSValue {
    guard let context = JSContext() else {
      throw CallbackError.contextCreationFailed
    }

    guard let callback = context.evaluateScript("(() => {})") else {
      throw CallbackError.callbackCreationFailed
    }

    return callback
  }
}

private enum CallbackError: Error {
  case contextCreationFailed
  case callbackCreationFailed
}
