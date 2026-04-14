import CoreGraphics

final class ShortcutTap: ShortcutTapType {
  typealias EventHandler = (CGEventType, CGEvent) -> Unmanaged<CGEvent>?

  private var eventHandler: EventHandler?
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var runLoop: CFRunLoop?
  private var isInvalidated = false

  private init(eventHandler: @escaping EventHandler) {
    self.eventHandler = eventHandler
  }

  deinit {
    invalidate()
  }

  func enable(_ enabled: Bool) {
    guard let eventTap else { return }
    CGEvent.tapEnable(tap: eventTap, enable: enabled)
  }

  func invalidate() {
    guard !isInvalidated else { return }
    isInvalidated = true

    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      CFMachPortInvalidate(eventTap)
    }

    if let runLoopSource, let runLoop {
      CFRunLoopRemoveSource(runLoop, runLoopSource, .commonModes)
    }

    eventTap = nil
    runLoopSource = nil
    runLoop = nil
    eventHandler = nil
  }

  static func makeLive(eventHandler: @escaping EventHandler) -> ShortcutTap? {
    let shortcutTap = ShortcutTap(eventHandler: eventHandler)
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: shortcutTapCallback,
        userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(shortcutTap).toOpaque())
      )
    else {
      log("could not create shortcut event tap", level: .error)
      return nil
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    let runLoop = CFRunLoopGetCurrent()

    CFRunLoopAddSource(runLoop, runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)

    shortcutTap.eventTap = eventTap
    shortcutTap.runLoopSource = runLoopSource
    shortcutTap.runLoop = runLoop

    return shortcutTap
  }

  fileprivate func handleCallback(_ type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    guard let eventHandler else {
      return Unmanaged.passUnretained(event)
    }

    return eventHandler(type, event)
  }
}

private func shortcutTapCallback(
  proxy _: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let userInfo else {
    return Unmanaged.passUnretained(event)
  }

  let shortcutTap = Unmanaged<ShortcutTap>.fromOpaque(userInfo).takeUnretainedValue()
  return shortcutTap.handleCallback(type, event: event)
}
