import Foundation
import Testing

@testable import Stark

private final class RecordingShortcutRegistrar: ShortcutRegistrar {
  var registeredHotKeyIDs = [UInt32]()
  var unregisteredHotKeyIDs = [UInt32]()
  var installEventHandlerCallCount = 0
  var removeEventHandlerCallCount = 0

  func register(keyCode _: UInt32, modifiers _: UInt32, hotKeyID: UInt32, signature _: OSType)
    -> Bool
  {
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

@Suite(.serialized) struct ShortcutManagerTests {
  @Test func registerTracksOneShortcut() {
    let registrar = prepareRegistrar()
    defer { resetState() }

    ShortcutManager.register(shortcut: shortcut(id: "A"))

    #expect(ShortcutManager.registeredShortcutCount == 1)
    #expect(registrar.registeredHotKeyIDs == [1])
  }

  @Test func duplicateIdentifiersAreIgnored() {
    let registrar = prepareRegistrar()
    defer { resetState() }

    let id = uuid("duplicate")
    ShortcutManager.register(shortcut: shortcut(id: id))
    ShortcutManager.register(shortcut: shortcut(id: id))

    #expect(ShortcutManager.registeredShortcutCount == 1)
    #expect(registrar.registeredHotKeyIDs == [1])
  }

  @Test func registerShortcutsRegistersBatch() {
    let registrar = prepareRegistrar()
    defer { resetState() }

    ShortcutManager.register(shortcuts: [
      shortcut(id: "A"),
      shortcut(id: "B"),
      shortcut(id: "C"),
    ])

    #expect(ShortcutManager.registeredShortcutCount == 3)
    #expect(registrar.registeredHotKeyIDs == [1, 2, 3])
  }

  @Test func unregisterRemovesMatchingShortcutOnly() {
    let registrar = prepareRegistrar()
    defer { resetState() }

    let first = shortcut(id: "A")
    let second = shortcut(id: "B")

    ShortcutManager.register(shortcut: first)
    ShortcutManager.register(shortcut: second)
    ShortcutManager.unregister(shortcut: first)

    #expect(ShortcutManager.registeredShortcutCount == 1)
    #expect(registrar.unregisteredHotKeyIDs == [1])
  }

  @Test func resetClearsAllTrackedShortcuts() {
    let registrar = prepareRegistrar()
    defer { resetState() }

    ShortcutManager.register(shortcuts: [
      shortcut(id: "A"),
      shortcut(id: "B"),
    ])

    ShortcutManager.reset()

    #expect(ShortcutManager.registeredShortcutCount == 0)
    #expect(registrar.unregisteredHotKeyIDs.sorted() == [1, 2])
  }

  @Test func startInstallsHandlerWhenShortcutsExist() {
    let registrar = prepareRegistrar()
    defer { resetState() }

    ShortcutManager.start()
    #expect(registrar.installEventHandlerCallCount == 0)

    ShortcutManager.register(shortcut: shortcut(id: "A"))
    ShortcutManager.start()
    ShortcutManager.start()

    #expect(registrar.installEventHandlerCallCount == 2)
  }

  @Test func stopRemovesEventHandler() {
    let registrar = prepareRegistrar()
    defer { resetState() }

    ShortcutManager.stop()

    #expect(registrar.removeEventHandlerCallCount == 1)
  }

  @Test func resetForTestingClearsState() {
    let registrar = prepareRegistrar()

    ShortcutManager.register(shortcuts: [
      shortcut(id: "A"),
      shortcut(id: "B"),
    ])
    ShortcutManager.resetForTesting()

    #expect(ShortcutManager.registeredShortcutCount == 0)
    #expect(registrar.unregisteredHotKeyIDs.sorted() == [1, 2])
  }

  private func prepareRegistrar() -> RecordingShortcutRegistrar {
    resetState()
    let registrar = RecordingShortcutRegistrar()
    ShortcutManager.useRegistrar(registrar)
    return registrar
  }

  private func resetState() {
    ShortcutManager.resetForTesting()
  }

  private func shortcut(id: String) -> Shortcut {
    var shortcut = Shortcut(identifier: uuid(id))
    shortcut.keyCode = 36
    shortcut.modifierFlags = 256
    return shortcut
  }

  private func shortcut(id: UUID) -> Shortcut {
    var shortcut = Shortcut(identifier: id)
    shortcut.keyCode = 36
    shortcut.modifierFlags = 256
    return shortcut
  }

  private func uuid(_ value: String) -> UUID {
    switch value {
    case "A":
      UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    case "B":
      UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    case "C":
      UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!
    case "duplicate":
      UUID(uuidString: "00000000-0000-0000-0000-0000000000DD")!
    default:
      fatalError("Unhandled test shortcut id: \(value)")
    }
  }
}
