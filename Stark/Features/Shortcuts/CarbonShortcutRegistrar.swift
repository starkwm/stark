import Carbon

final class CarbonShortcutRegistrar: ShortcutRegistrar {
  private var eventHotKeys = [UInt32: EventHotKeyRef]()
  private var eventHandler: EventHandlerRef?

  /// Registers a Carbon hotkey and retains its reference for later cleanup.
  func register(keyCode: UInt32, modifiers: UInt32, hotKeyID: UInt32, signature: OSType) -> Bool {
    let keyID = EventHotKeyID(signature: signature, id: hotKeyID)
    var eventHotKeyRef: EventHotKeyRef?

    let registerErr = RegisterEventHotKey(
      keyCode,
      modifiers,
      keyID,
      GetEventDispatcherTarget(),
      0,
      &eventHotKeyRef
    )

    guard registerErr == noErr, let eventHotKeyRef else { return false }

    eventHotKeys[hotKeyID] = eventHotKeyRef
    return true
  }

  /// Unregisters a Carbon hotkey if its reference is still tracked.
  func unregister(hotKeyID: UInt32) {
    guard let eventHotKeyRef = eventHotKeys.removeValue(forKey: hotKeyID) else { return }

    UnregisterEventHotKey(eventHotKeyRef)
  }

  /// Installs the single dispatcher callback used for all registered shortcuts.
  func installEventHandler() -> Bool {
    guard eventHandler == nil else { return true }

    let eventSpec = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    ]

    let err = InstallEventHandler(
      GetEventDispatcherTarget(),
      shortcutEventHandler,
      1,
      eventSpec,
      nil,
      &eventHandler
    )

    return err == noErr
  }

  /// Removes the shared dispatcher callback when shortcut handling stops.
  func removeEventHandler() {
    guard let eventHandler else { return }

    RemoveEventHandler(eventHandler)
    self.eventHandler = nil
  }
}

private func shortcutEventHandler(
  _: EventHandlerCallRef?,
  event: EventRef?,
  _: UnsafeMutableRawPointer?
) -> OSStatus {
  ShortcutManager.handle(event: event)
}
