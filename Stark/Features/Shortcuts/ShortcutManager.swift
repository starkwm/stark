import Carbon

protocol ShortcutRegistrar: AnyObject {
  /// Registers a Carbon hotkey and associates it with a Stark-owned identifier.
  func register(keyCode: UInt32, modifiers: UInt32, hotKeyID: UInt32, signature: OSType) -> Bool
  /// Unregisters a previously installed Carbon hotkey.
  func unregister(hotKeyID: UInt32)
  /// Installs the shared Carbon hotkey event handler.
  func installEventHandler() -> Bool
  /// Removes the shared Carbon hotkey event handler.
  func removeEventHandler()
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

  /// Handles a Carbon hotkey event and dispatches it to the matching shortcut callback.
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

  /// Registers a single shortcut if it has not already been tracked.
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

  /// Registers a batch of shortcuts using the single-shortcut code path.
  static func register(shortcuts: [Shortcut]) {
    for shortcut in shortcuts {
      register(shortcut: shortcut)
    }
  }

  /// Removes a tracked shortcut and unregisters its Carbon hotkey.
  static func unregister(shortcut: Shortcut) {
    guard let box = box(for: shortcut) else { return }

    registrar.unregister(hotKeyID: box.carbonHotKeyID)

    box.shortcut = nil
    shortcuts.removeValue(forKey: box.carbonHotKeyID)
  }

  /// Unregisters every tracked shortcut while preserving allocated hotkey ids.
  static func reset() {
    for (_, box) in shortcuts {
      guard let shortcut = box.shortcut else { continue }
      unregister(shortcut: shortcut)
    }
  }

  /// Installs the shared event handler once at least one shortcut has been allocated.
  static func start() {
    guard shortcutsCount != 0 else { return }

    _ = registrar.installEventHandler()
  }

  /// Removes the shared event handler without altering tracked shortcuts.
  static func stop() {
    registrar.removeEventHandler()
  }

  static var registeredShortcutCount: Int {
    shortcuts.count
  }

  static func useRegistrar(_ registrar: ShortcutRegistrar) {
    Self.registrar = registrar
  }

  /// Resets all shortcut state and restores the default registrar for isolated tests.
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
