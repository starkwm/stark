import CoreGraphics
import Foundation

protocol ShortcutTapType: AnyObject {
  func enable(_ enabled: Bool)
  func invalidate()
}

final class ShortcutManager {
  typealias HandlerInvoker = (@escaping () -> Void) -> Void
  typealias EventHandler = (CGEventType, CGEvent) -> Unmanaged<CGEvent>?
  typealias TapFactory = (@escaping EventHandler) -> ShortcutTapType?

  private static let defaultHandlerInvoker: HandlerInvoker = { handler in
    DispatchQueue.main.async(execute: handler)
  }
  private static let invocationLock = NSLock()
  private static var activeInvocationID: UUID?

  private var shortcutsByKeyCode = [UInt32: [Shortcut]]()
  private var shortcutByIdentifier = [UUID: Shortcut]()
  private var isStarted = false
  private var tap: ShortcutTapType?
  private var tapFactory: TapFactory?
  private var handlerInvoker = defaultHandlerInvoker
  private let pendingLock = NSLock()
  private var pendingInvocationID: UUID?

  init(
    tapFactory: TapFactory? = nil,
    handlerInvoker: @escaping HandlerInvoker = ShortcutManager.defaultHandlerInvoker
  ) {
    self.tapFactory = tapFactory
    self.handlerInvoker = handlerInvoker
  }

  func register(shortcut: Shortcut) {
    guard shortcutByIdentifier[shortcut.identifier] == nil else {
      return
    }

    removeShortcut(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)

    shortcutsByKeyCode[shortcut.keyCode, default: []].insert(shortcut, at: 0)
    shortcutByIdentifier[shortcut.identifier] = shortcut
    ensureTapState()
  }

  func unregister(shortcut: Shortcut) {
    removeShortcut(identifier: shortcut.identifier)
    ensureTapState()
  }

  func reset() {
    shortcutsByKeyCode.removeAll()
    shortcutByIdentifier.removeAll()
    ensureTapState()
  }

  func start() {
    isStarted = true
    ensureTapState()
  }

  func stop() {
    isStarted = false
    ensureTapState()
  }

  private func handleTapEvent(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    switch eventType {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
      return handleTapDisabled(event)
    case .keyDown:
      return handleKeyDown(event)
    default:
      return Unmanaged.passUnretained(event)
    }
  }

  private func handleKeyEvent(keyCode: UInt32, flags: CGEventFlags, isAutorepeat: Bool) -> Bool {
    guard !isAutorepeat else { return false }
    guard let matchedShortcut = matchingShortcut(for: keyCode, flags: flags) else { return false }

    if let handler = matchedShortcut.handler {
      guard beginInvocation(for: matchedShortcut.identifier) else {
        recordPendingInvocation(for: matchedShortcut.identifier)
        return true
      }

      dispatchInvocation(for: matchedShortcut.identifier, handler: handler)
    }

    return true
  }

  private func ensureTapState() {
    guard isStarted, !shortcutByIdentifier.isEmpty else {
      tearDownTap()
      return
    }

    guard tap == nil else { return }

    tap = (tapFactory ?? ShortcutTap.makeLive)(makeEventHandler())
  }

  private func tearDownTap() {
    guard let tap else { return }

    tap.enable(false)
    tap.invalidate()
    self.tap = nil
  }

  private func makeEventHandler() -> EventHandler {
    { [weak self] type, event in
      guard let self else {
        return Unmanaged.passUnretained(event)
      }

      return self.handleTapEvent(eventType: type, event: event)
    }
  }

  private func handleTapDisabled(_ event: CGEvent) -> Unmanaged<CGEvent> {
    tearDownTap()
    ensureTapState()
    return Unmanaged.passUnretained(event)
  }

  private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
    let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
    let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

    guard !handleKeyEvent(keyCode: keyCode, flags: event.flags, isAutorepeat: isAutorepeat) else {
      return nil
    }

    return Unmanaged.passUnretained(event)
  }

  private func matchingShortcut(for keyCode: UInt32, flags: CGEventFlags) -> Shortcut? {
    let eventModifiers = Modifier.from(flags)

    return shortcutsByKeyCode[keyCode]?.first(where: {
      Modifier.compare($0.modifiers, eventModifiers)
    })
  }

  private func removeShortcut(keyCode: UInt32, modifiers: Modifier) {
    guard let shortcuts = shortcutsByKeyCode[keyCode] else { return }

    let remainingShortcuts = shortcuts.filter { shortcut in
      shortcut.keyCode != keyCode || shortcut.modifiers != modifiers
    }

    if let replacedShortcut = shortcuts.first(where: {
      $0.keyCode == keyCode && $0.modifiers == modifiers
    }) {
      shortcutByIdentifier.removeValue(forKey: replacedShortcut.identifier)
    }

    if remainingShortcuts.isEmpty {
      shortcutsByKeyCode.removeValue(forKey: keyCode)
    } else {
      shortcutsByKeyCode[keyCode] = remainingShortcuts
    }
  }

  private func removeShortcut(identifier: UUID) {
    guard let shortcut = shortcutByIdentifier.removeValue(forKey: identifier) else { return }
    guard let shortcuts = shortcutsByKeyCode[shortcut.keyCode] else { return }

    finishInvocation(for: identifier)
    clearPendingInvocation(for: identifier)

    let remainingShortcuts = shortcuts.filter { shortcut in
      shortcut.identifier != identifier
    }

    if remainingShortcuts.isEmpty {
      shortcutsByKeyCode.removeValue(forKey: shortcut.keyCode)
    } else {
      shortcutsByKeyCode[shortcut.keyCode] = remainingShortcuts
    }
  }

  private func beginInvocation(for identifier: UUID) -> Bool {
    Self.invocationLock.lock()
    defer { Self.invocationLock.unlock() }

    if Self.activeInvocationID != nil {
      return false
    }

    Self.activeInvocationID = identifier
    return true
  }

  private func finishInvocation(for identifier: UUID) {
    Self.invocationLock.lock()
    if Self.activeInvocationID == identifier {
      Self.activeInvocationID = nil
    }
    Self.invocationLock.unlock()
  }

  private func dispatchInvocation(for identifier: UUID, handler: @escaping () -> Void) {
    handlerInvoker { [weak self] in
      defer { self?.completeInvocation(for: identifier) }
      handler()
    }
  }

  private func completeInvocation(for identifier: UUID) {
    finishInvocation(for: identifier)
    dispatchPendingInvocation()
  }

  private func dispatchPendingInvocation() {
    while let identifier = takePendingInvocation() {
      guard beginInvocation(for: identifier) else {
        recordPendingInvocation(for: identifier)
        return
      }

      guard let handler = shortcutByIdentifier[identifier]?.handler else {
        finishInvocation(for: identifier)
        continue
      }

      dispatchInvocation(for: identifier, handler: handler)
      return
    }
  }

  private func recordPendingInvocation(for identifier: UUID) {
    pendingLock.lock()
    pendingInvocationID = identifier
    pendingLock.unlock()
  }

  private func takePendingInvocation() -> UUID? {
    pendingLock.lock()
    let identifier = pendingInvocationID
    pendingInvocationID = nil
    pendingLock.unlock()
    return identifier
  }

  private func clearPendingInvocation(for identifier: UUID) {
    pendingLock.lock()
    if pendingInvocationID == identifier {
      pendingInvocationID = nil
    }
    pendingLock.unlock()
  }

  static func resetInvocationStateForTesting() {
    invocationLock.lock()
    activeInvocationID = nil
    invocationLock.unlock()
  }
}
