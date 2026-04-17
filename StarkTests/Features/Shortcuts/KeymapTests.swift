import IOKit.hidsystem
import JavaScriptCore
import Testing

@testable import Stark

private final class TestShortcutTapRecorder {
  final class SpyShortcutTap: ShortcutTapType {
    let enableHandler: (Bool) -> Void
    let invalidateHandler: () -> Void

    init(enableHandler: @escaping (Bool) -> Void, invalidateHandler: @escaping () -> Void) {
      self.enableHandler = enableHandler
      self.invalidateHandler = invalidateHandler
    }

    func enable(_ enabled: Bool) {
      enableHandler(enabled)
    }

    func invalidate() {
      invalidateHandler()
    }
  }

  var createCallCount = 0
  var invalidateCallCount = 0
  var eventHandler: ShortcutManager.EventHandler?

  func makeTap() -> ShortcutManager.TapFactory {
    { eventHandler in
      self.createCallCount += 1
      self.eventHandler = eventHandler
      return SpyShortcutTap(
        enableHandler: { _ in },
        invalidateHandler: {
          self.invalidateCallCount += 1
        }
      )
    }
  }
}

@Suite(.serialized)
struct KeymapTests {
  @Test
  func createsStableIdentifiers() throws {
    let session = ConfigSession()
    let callbackState = CallbackState()

    let keymap = session.keymapBridge.on(
      "return",
      ["cmd", "shift"],
      try callback(in: callbackState.context)
    )

    #expect(keymap.id == "return[cmd|shift]")
  }

  @Test
  func preservesRawSidedModifierIdentifiers() throws {
    let session = ConfigSession()
    let callbackState = CallbackState()

    let keymap = session.keymapBridge.on(
      "return",
      ["lcmd", "shift"],
      try callback(in: callbackState.context)
    )

    #expect(keymap.id == "return[lcmd|shift]")
  }

  @Test
  func specialKeysKeepRawIdentifiersWhileInjectingFnInternally() throws {
    let (manager, tapRecorder, session, callbackState) = prepareState()
    var activeSession: ConfigSession?
    defer { activeSession?.deactivate() }

    _ = session.keymapBridge.on("left", ["cmd"], try callback(in: callbackState.context))
    apply(session, with: manager, activeSession: &activeSession)

    #expect(
      dispatchKeyDown(
        with: tapRecorder,
        keyCode: 123,
        flags: [.maskCommand, .maskSecondaryFn]
      ) == nil
    )
    #expect(callbackState.callCount() == 1)
  }

  @Test
  func removedAliasDoesNotRegisterShortcut() throws {
    let (manager, tapRecorder, session, callbackState) = prepareState()
    var activeSession: ConfigSession?
    defer { activeSession?.deactivate() }

    let keymap = session.keymapBridge.on(
      "return",
      ["option"],
      try callback(in: callbackState.context)
    )
    apply(session, with: manager, activeSession: &activeSession)

    #expect(keymap.id == "return[option]")
    #expect(tapRecorder.createCallCount == 0)
    #expect(dispatchKeyDown(with: tapRecorder) == nil)
    #expect(callbackState.callCount() == 0)
  }

  @Test
  func overwritesDuplicateActiveRegistrations() throws {
    let (manager, tapRecorder, session, callbackState) = prepareState()
    var activeSession: ConfigSession?
    defer { activeSession?.deactivate() }

    _ = session.keymapBridge.on("return", ["cmd"], try callback(in: callbackState.context))
    _ = session.keymapBridge.on("return", ["cmd"], try callback(in: callbackState.context))
    apply(session, with: manager, activeSession: &activeSession)

    #expect(dispatchKeyDown(with: tapRecorder) == nil)
    #expect(callbackState.callCount() == 1)
  }

  @Test
  func replacingActiveSessionSwapsRegisteredKeymaps() throws {
    let (manager, tapRecorder, session, callbackState) = prepareState()
    var activeSession: ConfigSession?
    defer { activeSession?.deactivate() }

    _ = session.keymapBridge.on("return", ["cmd"], try callback(in: callbackState.context))
    apply(session, with: manager, activeSession: &activeSession)

    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 36, flags: [.maskCommand]) == nil)

    let replacement = ConfigSession()
    _ = replacement.keymapBridge.on("escape", ["shift"], try callback(in: callbackState.context))
    apply(replacement, with: manager, activeSession: &activeSession)

    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 36, flags: [.maskCommand]) != nil)
    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 53, flags: [.maskShift]) == nil)
    #expect(callbackState.callCount() == 2)
  }

  @Test
  func discardingCandidateSessionPreservesActiveKeymaps() throws {
    let (manager, tapRecorder, session, callbackState) = prepareState()
    var activeSession: ConfigSession?
    defer { activeSession?.deactivate() }

    _ = session.keymapBridge.on("return", ["cmd"], try callback(in: callbackState.context))
    apply(session, with: manager, activeSession: &activeSession)

    let discarded = ConfigSession()
    _ = discarded.keymapBridge.on("escape", ["shift"], try callback(in: callbackState.context))
    discarded.deactivate()

    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 36, flags: [.maskCommand]) == nil)
    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 53, flags: [.maskShift]) != nil)
    #expect(callbackState.callCount() == 1)
  }

  @Test
  func offAndResetClearRegisteredState() throws {
    let (manager, tapRecorder, session, callbackState) = prepareState()
    var activeSession: ConfigSession?
    defer { activeSession?.deactivate() }

    _ = session.keymapBridge.on("return", ["cmd"], try callback(in: callbackState.context))
    _ = session.keymapBridge.on("escape", ["shift"], try callback(in: callbackState.context))
    apply(session, with: manager, activeSession: &activeSession)

    session.keymapBridge.off("return[cmd]")
    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 36, flags: [.maskCommand]) != nil)
    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 53, flags: [.maskShift]) == nil)

    session.resetKeymaps()
    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 53, flags: [.maskShift]) != nil)
    #expect(callbackState.callCount() == 1)
  }

  @Test
  func repeatedKeypressesKeepInvokingJavascriptCallback() throws {
    let (manager, tapRecorder, session, callbackState) = prepareState()
    var activeSession: ConfigSession?
    defer { activeSession?.deactivate() }

    _ = session.keymapBridge.on("return", ["cmd"], try callback(in: callbackState.context))
    apply(session, with: manager, activeSession: &activeSession)

    for _ in 0..<50 {
      #expect(dispatchKeyDown(with: tapRecorder) == nil)
    }

    #expect(callbackState.callCount() == 50)
  }

  private func prepareState() -> (
    ShortcutManager, TestShortcutTapRecorder, ConfigSession, CallbackState
  ) {
    ShortcutManager.resetInvocationStateForTesting()
    let tapRecorder = TestShortcutTapRecorder()
    let manager = ShortcutManager(
      tapFactory: tapRecorder.makeTap(),
      handlerInvoker: { handler in handler() }
    )

    return (manager, tapRecorder, ConfigSession(), CallbackState())
  }

  private func apply(
    _ session: ConfigSession,
    with manager: ShortcutManager,
    activeSession: inout ConfigSession?
  ) {
    manager.stop()
    manager.reset()
    activeSession?.deactivate()
    activeSession = session
    session.activate(with: manager)
    manager.start()
  }

  private func callback(in context: JSContext) throws -> JSValue {
    guard let callback = context.evaluateScript("(() => { globalThis.calls += 1 })") else {
      throw CallbackError.callbackCreationFailed
    }

    return callback
  }

  private func dispatchKeyDown(
    with tapRecorder: TestShortcutTapRecorder,
    keyCode: UInt32 = 36,
    flags: [CGEventFlags] = [.maskCommand],
    deviceMasks: [Int32] = [NX_DEVICELCMDKEYMASK]
  ) -> Unmanaged<CGEvent>? {
    let event = CGEvent(
      keyboardEventSource: nil,
      virtualKey: CGKeyCode(keyCode),
      keyDown: true
    )!
    event.flags = eventFlags(flags, deviceMasks: deviceMasks)
    return tapRecorder.eventHandler?(.keyDown, event)
  }

  private func eventFlags(_ flags: [CGEventFlags], deviceMasks: [Int32] = []) -> CGEventFlags {
    let rawValue =
      flags.reduce(CGEventFlags()) { $0.union($1) }.rawValue
      | UInt64(UInt32(bitPattern: deviceMasks.reduce(0, |)))
    return CGEventFlags(rawValue: rawValue)
  }
}

private final class CallbackState {
  let context: JSContext

  init() {
    context = JSContext()!
    _ = context.evaluateScript("globalThis.calls = 0")
  }

  func callCount() -> Int {
    Int(context.objectForKeyedSubscript("calls").toInt32())
  }
}

private enum CallbackError: Error {
  case callbackCreationFailed
}
