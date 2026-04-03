import Carbon
import CoreGraphics
import Foundation
import IOKit.hidsystem
import Testing

@testable import Stark

private final class RecordingShortcutTapRecorder {
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
  var enableCalls = [Bool]()
  var eventHandler: ShortcutManager.EventHandler?

  func makeTap() -> ShortcutManager.TapFactory {
    { eventHandler in
      self.createCallCount += 1
      self.eventHandler = eventHandler
      return SpyShortcutTap(
        enableHandler: { enabled in
          self.enableCalls.append(enabled)
        },
        invalidateHandler: {
          self.invalidateCallCount += 1
        }
      )
    }
  }
}

@Suite(.serialized) struct ShortcutManagerTests {
  @Test func registerTracksOneShortcut() {
    let (manager, tapRecorder) = prepareManager()

    manager.register(shortcut: shortcut(id: "A"))
    manager.start()

    #expect(tapRecorder.createCallCount == 1)
    #expect(dispatchKeyDown(with: tapRecorder) == nil)
  }

  @Test func duplicateIdentifiersAreIgnored() {
    let tapRecorder = RecordingShortcutTapRecorder()
    var firstCallCount = 0
    var secondCallCount = 0
    let manager = ShortcutManager(
      tapFactory: tapRecorder.makeTap(),
      handlerInvoker: { handler in handler() }
    )

    let id = uuid("duplicate")
    let first = shortcut(id: id, handler: { firstCallCount += 1 })
    let second = shortcut(id: id, keyCode: 53, handler: { secondCallCount += 1 })

    manager.register(shortcut: first)
    manager.register(shortcut: second)
    manager.start()

    _ = dispatchKeyDown(with: tapRecorder)
    #expect(firstCallCount == 1)
    #expect(secondCallCount == 0)
  }

  @Test func multipleRegistrationsRemainActive() {
    let (manager, tapRecorder) = prepareManager()

    manager.register(shortcut: shortcut(id: "A"))
    manager.register(shortcut: shortcut(id: "B", keyCode: 53))
    manager.register(shortcut: shortcut(id: "C", keyCode: 123))
    manager.start()

    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 36) == nil)
    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 53) == nil)
    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 123) == nil)
  }

  @Test func unregisterRemovesMatchingShortcutOnly() {
    let tapRecorder = RecordingShortcutTapRecorder()
    var firstCallCount = 0
    var secondCallCount = 0
    let manager = ShortcutManager(
      tapFactory: tapRecorder.makeTap(),
      handlerInvoker: { handler in handler() }
    )

    let first = shortcut(id: "A", handler: { firstCallCount += 1 })
    let second = shortcut(id: "B", keyCode: 53, handler: { secondCallCount += 1 })

    manager.register(shortcut: first)
    manager.register(shortcut: second)
    manager.unregister(shortcut: first)
    manager.start()

    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 36) != nil)
    #expect(dispatchKeyDown(with: tapRecorder, keyCode: 53) == nil)
    #expect(firstCallCount == 0)
    #expect(secondCallCount == 1)
  }

  @Test func resetClearsAllTrackedShortcuts() {
    let (manager, tapRecorder) = prepareManager()

    manager.register(shortcut: shortcut(id: "A"))
    manager.register(shortcut: shortcut(id: "B", keyCode: 53))
    manager.reset()
    manager.start()

    #expect(tapRecorder.createCallCount == 0)
  }

  @Test func duplicateBindingsUseLatestRegistration() {
    let tapRecorder = RecordingShortcutTapRecorder()
    var firstCallCount = 0
    var secondCallCount = 0
    let manager = ShortcutManager(
      tapFactory: tapRecorder.makeTap(),
      handlerInvoker: { handler in handler() }
    )

    let first = shortcut(id: "A", handler: { firstCallCount += 1 })
    let second = shortcut(id: "B", handler: { secondCallCount += 1 })

    manager.register(shortcut: first)
    manager.register(shortcut: second)
    manager.start()

    #expect(dispatchKeyDown(with: tapRecorder) == nil)
    #expect(firstCallCount == 0)
    #expect(secondCallCount == 1)
  }

  @Test func leftCommandMatchesOnlyLeftCommand() {
    let (manager, tapRecorder) = prepareManager(handlerInvoker: { $0() })

    var callCount = 0
    let leftShortcut = shortcut(id: "A", modifiers: [.lcmd], handler: { callCount += 1 })

    manager.register(shortcut: leftShortcut)
    manager.start()

    #expect(
      dispatchKeyDown(
        with: tapRecorder,
        flags: eventFlags([.maskCommand], deviceMasks: [NX_DEVICELCMDKEYMASK])
      ) == nil
    )
    #expect(
      dispatchKeyDown(
        with: tapRecorder,
        flags: eventFlags([.maskCommand], deviceMasks: [NX_DEVICERCMDKEYMASK])
      ) != nil
    )
    #expect(callCount == 1)
  }

  @Test func rightCommandMatchesOnlyRightCommand() {
    let (manager, tapRecorder) = prepareManager(handlerInvoker: { $0() })

    var callCount = 0
    let rightShortcut = shortcut(id: "A", modifiers: [.rcmd], handler: { callCount += 1 })

    manager.register(shortcut: rightShortcut)
    manager.start()

    #expect(
      dispatchKeyDown(
        with: tapRecorder,
        flags: eventFlags([.maskCommand], deviceMasks: [NX_DEVICERCMDKEYMASK])
      ) == nil
    )
    #expect(
      dispatchKeyDown(
        with: tapRecorder,
        flags: eventFlags([.maskCommand], deviceMasks: [NX_DEVICELCMDKEYMASK])
      ) != nil
    )
    #expect(callCount == 1)
  }

  @Test func genericCommandMatchesEitherSide() {
    let (manager, tapRecorder) = prepareManager(handlerInvoker: { $0() })

    var callCount = 0
    let shortcut = shortcut(id: "A", modifiers: [.cmd], handler: { callCount += 1 })

    manager.register(shortcut: shortcut)
    manager.start()

    #expect(
      dispatchKeyDown(
        with: tapRecorder,
        flags: eventFlags([.maskCommand], deviceMasks: [NX_DEVICELCMDKEYMASK])
      ) == nil
    )
    #expect(
      dispatchKeyDown(
        with: tapRecorder,
        flags: eventFlags([.maskCommand], deviceMasks: [NX_DEVICERCMDKEYMASK])
      ) == nil
    )
    #expect(callCount == 2)
  }

  @Test func fnMatchesExactly() {
    let (manager, tapRecorder) = prepareManager(handlerInvoker: { $0() })

    var callCount = 0
    let shortcut = shortcut(id: "A", modifiers: [.fn], handler: { callCount += 1 })

    manager.register(shortcut: shortcut)
    manager.start()

    #expect(dispatchKeyDown(with: tapRecorder, flags: eventFlags([.maskSecondaryFn])) == nil)
    #expect(dispatchKeyDown(with: tapRecorder, flags: eventFlags([.maskCommand])) != nil)
    #expect(callCount == 1)
  }

  @Test func cmdLeftMatchesSkbdStyleFnAwareBinding() {
    let (manager, tapRecorder) = prepareManager(handlerInvoker: { $0() })

    var callCount = 0
    let shortcut = shortcut(
      id: "A",
      keyCode: UInt32(kVK_LeftArrow),
      modifiers: [.cmd, .fn],
      handler: { callCount += 1 }
    )

    manager.register(shortcut: shortcut)
    manager.start()

    #expect(
      dispatchKeyDown(
        with: tapRecorder,
        keyCode: UInt32(kVK_LeftArrow),
        flags: eventFlags([.maskCommand, .maskSecondaryFn], deviceMasks: [NX_DEVICELCMDKEYMASK])
      ) == nil
    )
    #expect(callCount == 1)
  }

  @Test func startCreatesTapOnceWhenShortcutsExist() {
    let (manager, tapRecorder) = prepareManager()

    manager.start()
    #expect(tapRecorder.createCallCount == 0)

    manager.register(shortcut: shortcut(id: "A"))
    manager.start()
    manager.start()

    #expect(tapRecorder.createCallCount == 1)
  }

  @Test func stopTearsDownActiveTap() {
    let (manager, tapRecorder) = prepareManager()

    manager.register(shortcut: shortcut(id: "A"))
    manager.start()
    manager.stop()

    #expect(tapRecorder.invalidateCallCount == 1)
  }

  @Test func resetClearsInstanceState() {
    let (manager, tapRecorder) = prepareManager()

    manager.register(shortcut: shortcut(id: "A"))
    manager.register(shortcut: shortcut(id: "B", keyCode: 53))
    manager.reset()
    manager.start()

    #expect(tapRecorder.createCallCount == 0)
  }

  @Test func matchedKeyEventInvokesHandlerAndSwallowsEvent() {
    let (manager, tapRecorder) = prepareManager(handlerInvoker: { $0() })

    var callCount = 0
    let shortcut = shortcut(id: "A", modifiers: [.cmd, .shift], handler: { callCount += 1 })

    manager.register(shortcut: shortcut)
    manager.start()

    let swallowed = dispatchKeyDown(
      with: tapRecorder,
      flags: eventFlags([.maskCommand, .maskShift])
    )

    #expect(swallowed == nil)
    #expect(callCount == 1)
  }

  @Test func unmatchedKeyEventPassesThrough() {
    let (manager, tapRecorder) = prepareManager()

    manager.register(shortcut: shortcut(id: "A"))
    manager.start()

    let result = dispatchKeyDown(with: tapRecorder, keyCode: 53)

    #expect(result != nil)
  }

  @Test func autorepeatKeyEventIsIgnored() {
    let (manager, tapRecorder) = prepareManager(handlerInvoker: { $0() })

    var callCount = 0
    let shortcut = shortcut(id: "A", handler: { callCount += 1 })

    manager.register(shortcut: shortcut)
    manager.start()

    let result = dispatchKeyDown(with: tapRecorder, isAutorepeat: true)

    #expect(result != nil)
    #expect(callCount == 0)
  }

  @Test func unregisteringLastShortcutTearsDownTap() {
    let (manager, tapRecorder) = prepareManager()

    let first = shortcut(id: "A")
    manager.register(shortcut: first)
    manager.start()

    #expect(tapRecorder.createCallCount == 1)

    manager.unregister(shortcut: first)

    #expect(tapRecorder.invalidateCallCount == 1)
  }

  @Test func tapDisabledEventsReEnableActiveTap() {
    let (manager, tapRecorder) = prepareManager()

    manager.register(shortcut: shortcut(id: "A"))
    manager.start()

    let event = keyDownEvent(keyCode: UInt32(kVK_Return), flags: eventFlags([.maskCommand]))

    _ = tapRecorder.eventHandler?(.tapDisabledByTimeout, event)
    _ = tapRecorder.eventHandler?(.tapDisabledByUserInput, event)

    #expect(tapRecorder.enableCalls == [true, true])
  }

  @Test func eventTapCallbackSwallowsMatchedShortcut() {
    let (manager, tapRecorder) = prepareManager(handlerInvoker: { $0() })

    var callCount = 0
    let shortcut = shortcut(id: "A", handler: { callCount += 1 })

    manager.register(shortcut: shortcut)
    manager.start()

    let result = dispatchKeyDown(with: tapRecorder)

    #expect(result == nil)
    #expect(callCount == 1)
  }

  private func prepareManager(
    handlerInvoker: @escaping ShortcutManager.HandlerInvoker = { handler in
      DispatchQueue.main.async(execute: handler)
    }
  ) -> (ShortcutManager, RecordingShortcutTapRecorder) {
    let tapRecorder = RecordingShortcutTapRecorder()
    let manager = ShortcutManager(
      tapFactory: tapRecorder.makeTap(),
      handlerInvoker: handlerInvoker
    )
    return (manager, tapRecorder)
  }

  private func dispatchKeyDown(
    with tapRecorder: RecordingShortcutTapRecorder,
    keyCode: UInt32 = 36,
    flags: CGEventFlags = eventFlags([.maskCommand], deviceMasks: [NX_DEVICELCMDKEYMASK]),
    isAutorepeat: Bool = false
  ) -> Unmanaged<CGEvent>? {
    let event = keyDownEvent(keyCode: keyCode, flags: flags, isAutorepeat: isAutorepeat)
    return tapRecorder.eventHandler?(.keyDown, event)
  }

  private func keyDownEvent(
    keyCode: UInt32,
    flags: CGEventFlags,
    isAutorepeat: Bool = false
  ) -> CGEvent {
    let event = CGEvent(
      keyboardEventSource: nil,
      virtualKey: CGKeyCode(keyCode),
      keyDown: true
    )!
    event.flags = flags
    event.setIntegerValueField(.keyboardEventAutorepeat, value: isAutorepeat ? 1 : 0)
    return event
  }

  private func shortcut(
    id: String,
    keyCode: UInt32 = 36,
    modifiers: Modifier = [.cmd],
    handler: (() -> Void)? = nil
  ) -> Shortcut {
    shortcut(id: uuid(id), keyCode: keyCode, modifiers: modifiers, handler: handler)
  }

  private func shortcut(
    id: UUID,
    keyCode: UInt32 = 36,
    modifiers: Modifier = [.cmd],
    handler: (() -> Void)? = nil
  ) -> Shortcut {
    Shortcut(identifier: id, keyCode: keyCode, modifiers: modifiers, handler: handler)
  }

  private static func eventFlags(
    _ flags: [CGEventFlags],
    deviceMasks: [Int32] = []
  ) -> CGEventFlags {
    let rawValue =
      flags.reduce(CGEventFlags()) { $0.union($1) }.rawValue
      | UInt64(UInt32(bitPattern: deviceMasks.reduce(0, |)))
    return CGEventFlags(rawValue: rawValue)
  }

  private func eventFlags(_ flags: [CGEventFlags], deviceMasks: [Int32] = []) -> CGEventFlags {
    Self.eventFlags(flags, deviceMasks: deviceMasks)
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
