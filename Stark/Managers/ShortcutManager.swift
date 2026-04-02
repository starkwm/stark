import Carbon

protocol ShortcutRegistrar: AnyObject {
  func register(keyCode: UInt32, modifiers: UInt32, hotKeyID: UInt32, signature: OSType) -> Bool
  func unregister(hotKeyID: UInt32)
  func installEventHandler() -> Bool
  func removeEventHandler()
}

final class CarbonShortcutRegistrar: ShortcutRegistrar {
  private var eventHotKeys = [UInt32: EventHotKeyRef]()
  private var eventHandler: EventHandlerRef?

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

  func unregister(hotKeyID: UInt32) {
    guard let eventHotKeyRef = eventHotKeys.removeValue(forKey: hotKeyID) else { return }

    UnregisterEventHotKey(eventHotKeyRef)
  }

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

  func removeEventHandler() {
    guard let eventHandler else { return }

    RemoveEventHandler(eventHandler)
    self.eventHandler = nil
  }
}

enum ShortcutManager {
  final class ShortcutBox {
    let identifier: UUID

    var shortcut: Shortcut?
    let carbonHotKeyID: UInt32

    init(shortcut: Shortcut, carbonHotKeyID: UInt32) {
      identifier = shortcut.identifier
      self.shortcut = shortcut
      self.carbonHotKeyID = carbonHotKeyID
    }
  }

  private static let signature = "strk".utf16.reduce(0) { ($0 << 8) + OSType($1) }

  private static var shortcuts = [UInt32: ShortcutBox]()
  private static var shortcutsCount: UInt32 = 0

  private static var registrar: ShortcutRegistrar = CarbonShortcutRegistrar()

  static func handle(event: EventRef?) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

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

    guard err == noErr else { return err }

    guard
      hotKeyID.signature == signature,
      let shortcut = shortcut(by: hotKeyID.id)
    else { return OSStatus(eventNotHandledErr) }

    shortcut.handler?()

    return noErr
  }

  static func register(shortcut: Shortcut) {
    guard !shortcuts.values.contains(where: { $0.identifier == shortcut.identifier }) else {
      return
    }

    shortcutsCount += 1

    let box = ShortcutBox(shortcut: shortcut, carbonHotKeyID: shortcutsCount)
    shortcuts[box.carbonHotKeyID] = box

    guard
      let keyCode = shortcut.keyCode,
      let keyModifiers = shortcut.modifierFlags
    else { return }

    _ = registrar.register(
      keyCode: keyCode,
      modifiers: keyModifiers,
      hotKeyID: box.carbonHotKeyID,
      signature: signature
    )
  }

  static func register(shortcuts: [Shortcut]) {
    for shortcut in shortcuts {
      register(shortcut: shortcut)
    }
  }

  static func unregister(shortcut: Shortcut) {
    guard let box = box(for: shortcut) else { return }

    registrar.unregister(hotKeyID: box.carbonHotKeyID)

    box.shortcut = nil
    shortcuts.removeValue(forKey: box.carbonHotKeyID)
  }

  static func reset() {
    for (_, box) in shortcuts {
      guard let shortcut = box.shortcut else { continue }
      unregister(shortcut: shortcut)
    }
  }

  static func start() {
    guard shortcutsCount != 0 else { return }

    _ = registrar.installEventHandler()
  }

  static func stop() {
    registrar.removeEventHandler()
  }

  static var registeredShortcutCount: Int {
    shortcuts.count
  }

  static func useRegistrar(_ registrar: ShortcutRegistrar) {
    Self.registrar = registrar
  }

  static func resetForTesting() {
    stop()
    reset()
    shortcuts.removeAll()
    shortcutsCount = 0
    registrar = CarbonShortcutRegistrar()
  }

  private static func shortcut(by id: UInt32) -> Shortcut? {
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

private func shortcutEventHandler(
  _: EventHandlerCallRef?,
  event: EventRef?,
  _: UnsafeMutableRawPointer?
) -> OSStatus {
  ShortcutManager.handle(event: event)
}
