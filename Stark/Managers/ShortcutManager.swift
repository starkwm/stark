import Carbon

public enum ShortcutManager {
  final class ShortcutBox {
    let identifier: UUID

    var shortcut: Shortcut?
    let carbonHotKeyID: UInt32

    var carbonEventHotKey: EventHotKeyRef?

    init(shortcut: Shortcut, carbonHotKeyID: UInt32) {
      identifier = shortcut.identifier
      self.shortcut = shortcut
      self.carbonHotKeyID = carbonHotKeyID
    }
  }

  private static let signature = "strk".utf16.reduce(0) { ($0 << 8) + OSType($1) }

  private static var shortcuts = [UInt32: ShortcutBox]()
  private static var shortcutsCount: UInt32 = 0

  private static var eventHandler: EventHandlerRef?

  static func handleCarbonEvent(_ event: EventRef?) -> OSStatus {
    guard let event = event else {
      return OSStatus(eventNotHandledErr)
    }

    var hotKeyID = EventHotKeyID()

    let err = GetEventParameter(
      event,
      UInt32(kEventParamDirectObject),
      UInt32(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &hotKeyID
    )

    if err != noErr {
      return err
    }

    guard hotKeyID.signature == signature, let shortcut = shortcut(for: hotKeyID.id) else {
      return OSStatus(eventNotHandledErr)
    }

    shortcut.handler()

    return noErr
  }

  public static func register(shortcut: Shortcut) {
    if shortcuts.values.contains(where: { $0.identifier == shortcut.identifier }) {
      return
    }

    shortcutsCount += 1

    let box = ShortcutBox(shortcut: shortcut, carbonHotKeyID: shortcutsCount)
    shortcuts[box.carbonHotKeyID] = box

    guard let keyCode = shortcut.keyCode, let keyModifiers = shortcut.modifierFlags else {
      return
    }

    let keyID = EventHotKeyID(signature: signature, id: box.carbonHotKeyID)
    var eventHotKeyRef: EventHotKeyRef?

    let registerErr = RegisterEventHotKey(
      keyCode,
      keyModifiers,
      keyID,
      GetEventDispatcherTarget(),
      0,
      &eventHotKeyRef
    )

    guard registerErr == noErr, eventHotKeyRef != nil else {
      return
    }

    box.carbonEventHotKey = eventHotKeyRef
  }

  public static func register(shortcuts: [Shortcut]) {
    for shortcut in shortcuts {
      self.register(shortcut: shortcut)
    }
  }

  public static func unregister(shortcut: Shortcut) {
    guard let box = box(for: shortcut) else {
      return
    }

    UnregisterEventHotKey(box.carbonEventHotKey)

    box.shortcut = nil
    shortcuts.removeValue(forKey: box.carbonHotKeyID)
  }

  public static func reset() {
    for (_, box) in shortcuts {
      guard let shortcut = box.shortcut else {
        continue
      }

      self.unregister(shortcut: shortcut)
    }
  }

  public static func start() {
    if shortcutsCount == 0 || eventHandler != nil {
      return
    }

    let eventSpec = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    ]

    InstallEventHandler(GetEventDispatcherTarget(), shortcutEventHandler, 1, eventSpec, nil, &eventHandler)
  }

  public static func stop() {
    if eventHandler != nil {
      RemoveEventHandler(eventHandler)
      eventHandler = nil
    }
  }

  private static func shortcut(for id: UInt32) -> Shortcut? {
    if let shortcut = shortcuts[id]?.shortcut {
      return shortcut
    }

    shortcuts.removeValue(forKey: id)
    return nil
  }

  private static func box(for shortcut: Shortcut) -> ShortcutBox? {
    for box in shortcuts.values where box.identifier == shortcut.identifier {
      return box
    }

    return nil
  }
}

private func shortcutEventHandler(_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
  ShortcutManager.handleCarbonEvent(event)
}
