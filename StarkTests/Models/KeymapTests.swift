import JavaScriptCore
import Testing

@testable import Stark

private final class TestShortcutRegistrar: ShortcutRegistrar {
  var registeredHotKeyIDs = [UInt32]()
  var unregisteredHotKeyIDs = [UInt32]()
  var installEventHandlerCallCount = 0
  var removeEventHandlerCallCount = 0

  func register(keyCode _: UInt32, modifiers _: UInt32, hotKeyID: UInt32, signature _: OSType) -> Bool {
    registeredHotKeyIDs.append(hotKeyID)
    return true
  }

  func unregister(hotKeyID: UInt32) {
    unregisteredHotKeyIDs.append(hotKeyID)
  }

  func installEventHandler() -> Bool {
    installEventHandlerCallCount += 1
    return true
  }

  func removeEventHandler() {
    removeEventHandlerCallCount += 1
  }
}

@Suite(.serialized) struct KeymapTests {
  @Test func createsStableIdentifiers() throws {
    resetState()
    let registrar = TestShortcutRegistrar()
    ShortcutManager.useRegistrar(registrar)
    defer { resetState() }

    let keymap = Keymap.on("return", ["cmd", "shift"], try callback())

    #expect(keymap.id == "return[cmd|shift]")
    #expect(Keymap.activeIDsForTesting == ["return[cmd|shift]"])
    #expect(ShortcutManager.registeredShortcutCount == 1)
  }

  @Test func overwritesDuplicateActiveRegistrations() throws {
    resetState()
    let registrar = TestShortcutRegistrar()
    ShortcutManager.useRegistrar(registrar)
    defer { resetState() }

    _ = Keymap.on("return", ["cmd"], try callback())
    _ = Keymap.on("return", ["cmd"], try callback())

    #expect(Keymap.activeIDsForTesting == ["return[cmd]"])
    #expect(ShortcutManager.registeredShortcutCount == 1)
    #expect(registrar.unregisteredHotKeyIDs.count == 1)
  }

  @Test func commitRecordingSwapsActiveKeymaps() throws {
    resetState()
    let registrar = TestShortcutRegistrar()
    ShortcutManager.useRegistrar(registrar)
    defer { resetState() }

    _ = Keymap.on("return", ["cmd"], try callback())

    Keymap.beginRecording()
    _ = Keymap.on("escape", ["shift"], try callback())

    #expect(Keymap.activeIDsForTesting == ["return[cmd]"])
    #expect(Keymap.recordingIDsForTesting == ["escape[shift]"])

    Keymap.commitRecording()

    #expect(Keymap.recordingIDsForTesting.isEmpty)
    #expect(Keymap.activeIDsForTesting == ["escape[shift]"])
    #expect(ShortcutManager.registeredShortcutCount == 1)
    #expect(registrar.unregisteredHotKeyIDs.count == 1)
  }

  @Test func discardRecordingPreservesActiveKeymaps() throws {
    resetState()
    let registrar = TestShortcutRegistrar()
    ShortcutManager.useRegistrar(registrar)
    defer { resetState() }

    _ = Keymap.on("return", ["cmd"], try callback())

    Keymap.beginRecording()
    _ = Keymap.on("escape", ["shift"], try callback())
    Keymap.discardRecording()

    #expect(Keymap.recordingIDsForTesting.isEmpty)
    #expect(Keymap.activeIDsForTesting == ["return[cmd]"])
    #expect(ShortcutManager.registeredShortcutCount == 1)
  }

  @Test func offAndResetClearRegisteredState() throws {
    resetState()
    let registrar = TestShortcutRegistrar()
    ShortcutManager.useRegistrar(registrar)
    defer { resetState() }

    _ = Keymap.on("return", ["cmd"], try callback())
    _ = Keymap.on("escape", ["shift"], try callback())

    Keymap.off("return[cmd]")
    #expect(Keymap.activeIDsForTesting == ["escape[shift]"])
    #expect(ShortcutManager.registeredShortcutCount == 1)

    Keymap.reset()
    #expect(Keymap.activeIDsForTesting.isEmpty)
    #expect(ShortcutManager.registeredShortcutCount == 0)
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

  private func resetState() {
    Keymap.resetForTesting()
    ShortcutManager.resetForTesting()
  }
}

private enum CallbackError: Error {
  case contextCreationFailed
  case callbackCreationFailed
}
