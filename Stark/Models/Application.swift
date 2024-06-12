import AppKit
import JavaScriptCore
import OSLog

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

@objc protocol ApplicationJSExport: JSExport {
  static func all() -> [Application]
  static func focused() -> Application?
  static func find(_ name: String) -> Application?

  var name: String { get }
  var bundleID: String { get }
  var processID: pid_t { get }

  var isFrontmost: Bool { get }
  var isHidden: Bool { get }
  var isTerminated: Bool { get }

  func windows() -> [Window]
  func activate() -> Bool
  func focus() -> Bool
  func show() -> Bool
  func hide() -> Bool
  func terminate() -> Bool
}

extension Application: ApplicationJSExport {}

extension Application {
  override var description: String {
    "<Application pid: \(processID), name: \(name), bundle: \(bundleID)>"
  }
}

class Application: NSObject {
  static func all() -> [Application] {
    return Array(WindowManager.shared.applications.values)
  }

  static func focused() -> Application? {
    guard let application = NSWorkspace.shared.frontmostApplication else { return nil }

    return WindowManager.shared.applications[application.processIdentifier]
  }

  static func find(_ name: String) -> Application? {
    return WindowManager.shared.applications.first(where: { $0.value.name == name })?.value
  }

  var name: String {
    application.localizedName ?? "nil"
  }

  var bundleID: String {
    application.bundleIdentifier ?? "nil"
  }

  var processID: pid_t {
    application.processIdentifier
  }

  var isFrontmost: Bool {
    application.isActive
  }

  var isHidden: Bool {
    var value: AnyObject?

    guard AXUIElementCopyAttributeValue(element, kAXHiddenAttribute as CFString, &value) == .success,
      let number = value as? NSNumber
    else {
      return false
    }

    return number.boolValue
  }

  var isTerminated: Bool {
    application.isTerminated
  }

  var connection: Int32 = -1
  var observer: AXObserver?
  var retryObserving = false

  private var application: NSRunningApplication

  private var element: AXUIElement
  private var observedNotifications = ApplicationNotifications(rawValue: 0)
  private var observing = false

  init(process: Process) {
    self.element = AXUIElementCreateApplication(process.pid)
    self.application = NSRunningApplication(processIdentifier: process.pid)!

    SLSGetConnectionIDForPSN(Space.connection, &process.psn, &self.connection)
  }

  deinit {
    Logger.main.debug("destroying application \(self, privacy: .public)")
  }

  func windows() -> [Window] {
    return WindowManager.shared.windows.values.filter { $0.application == self }
  }

  func activate() -> Bool {
    application.activate(options: .activateAllWindows)
  }

  func focus() -> Bool {
    application.activate(options: [])
  }

  func show() -> Bool {
    application.unhide()
  }

  func hide() -> Bool {
    application.hide()
  }

  func terminate() -> Bool {
    application.terminate()
  }

  func observe() -> Bool {
    if AXObserverCreate(application.processIdentifier, accessibilityObserverCallback, &observer) == .success {
      guard let observer = observer else {
        return false
      }

      let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(self).toOpaque()

      for (idx, notification) in applicationNotifications.enumerated() {
        let result = AXObserverAddNotification(observer, element, notification as CFString, context)

        if result == .success || result == .notificationAlreadyRegistered {
          observedNotifications.insert(ApplicationNotifications(rawValue: 1 << idx))
        } else {
          retryObserving = result == .cannotComplete

          Logger.main.debug(
            "notification \(notification, privacy: .public) not added \(self, privacy: .public) (retry: \(self.retryObserving))"
          )
        }
      }

      observing = true

      CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), CFRunLoopMode.defaultMode)
    }

    return observedNotifications.contains(.all)
  }

  func unobserve() {
    if !observing {
      return
    }

    guard let observer = observer else {
      return
    }

    for (idx, notification) in applicationNotifications.enumerated() {
      let notif = ApplicationNotifications(rawValue: 1 << idx)

      if observedNotifications.contains(notif) {
        AXObserverRemoveNotification(observer, element, notification as CFString)
        observedNotifications.remove(notif)
      }
    }

    CFRunLoopSourceInvalidate(AXObserverGetRunLoopSource(observer))

    self.observer = nil
    observing = false
  }

  func windowIdentifiers() -> [CGWindowID] {
    let spaces = Space.all().map(\.id) as CFArray

    let options: UInt32 = 0x7
    var setTags: UInt64 = 0
    var clearTags: UInt64 = 0

    let windows = SLSCopyWindowsWithOptionsAndTags(
      Space.connection,
      UInt32(connection),
      spaces,
      options,
      &setTags,
      &clearTags
    )

    let query = SLSWindowQueryWindows(Space.connection, windows, Int32(CFArrayGetCount(windows)))
    let iterator = SLSWindowQueryResultCopyWindows(query)

    var foundWindows = [CGWindowID]()

    while SLSWindowIteratorAdvance(iterator) {
      let attributes = SLSWindowIteratorGetAttributes(iterator)
      let tags = SLSWindowIteratorGetTags(iterator)
      let parentWindowID = SLSWindowIteratorGetParentID(iterator)
      let windowID = SLSWindowIteratorGetWindowID(iterator)

      if parentWindowID != 0 {
        continue
      }

      if ((attributes & 0x2) != 0 || (tags & 0x400_0000_0000_0000) != 0)
        && (((tags & 0x1) != 0) || ((tags & 0x2) != 0 && (tags & 0x8000_0000) != 0))
      {
        foundWindows.append(windowID)
      } else if (attributes == 0x0 || attributes == 0x1)
        && ((tags & 0x1000_0000_0000_0000) != 0 || (tags & 0x300_0000_0000_0000) != 0)
        && (((tags & 0x1) != 0) || ((tags & 0x2) != 0 && (tags & 0x8000_0000) != 0))
      {
        foundWindows.append(windowID)
      }
    }

    return foundWindows
  }

  func windowElements() -> [AXUIElement] {
    var values: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &values) != .success {
      return []
    }

    guard let windows = values as? [AXUIElement] else {
      return []
    }

    return windows
  }

  func enhancedUIWorkaround(callback: () -> Void) {
    let enhancedUserInterfaceEnabled = isEnhancedUserInterfaceEnabled()

    if enhancedUserInterfaceEnabled {
      AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanFalse)
    }

    callback()

    if enhancedUserInterfaceEnabled {
      AXUIElementSetAttributeValue(element, kAXEnhancedUserInterface as CFString, kCFBooleanTrue)
    }
  }

  private func isEnhancedUserInterfaceEnabled() -> Bool {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, kAXEnhancedUserInterface as CFString, &value)

    if result == .success, CFGetTypeID(value) == CFBooleanGetTypeID() {
      return CFBooleanGetValue((value as! CFBoolean))
    }

    return false
  }
}

private func accessibilityObserverCallback(
  _ observer: AXObserver,
  _ element: AXUIElement,
  _ notification: CFString,
  _ context: UnsafeMutableRawPointer?
) {
  guard let context = context else {
    return
  }

  switch notification as String {
  case kAXCreatedNotification:
    EventManager.shared.post(event: .windowCreated, object: element)
  case kAXFocusedWindowChangedNotification:
    EventManager.shared.post(event: .windowFocused, object: Window.id(for: element))
  case kAXWindowMovedNotification:
    EventManager.shared.post(event: .windowMoved, object: Window.id(for: element))
  case kAXWindowResizedNotification:
    EventManager.shared.post(event: .windowResized, object: Window.id(for: element))
  case kAXWindowMiniaturizedNotification:
    let window = Unmanaged<Window>.fromOpaque(context).takeUnretainedValue()
    EventManager.shared.post(event: .windowMinimized, object: window)
  case kAXWindowDeminiaturizedNotification:
    let window = Unmanaged<Window>.fromOpaque(context).takeUnretainedValue()
    EventManager.shared.post(event: .windowDeminimized, object: window)
  case kAXUIElementDestroyedNotification:
    let windowID = Window.id(for: element)

    if windowID == 0 {
      break
    }

    guard let window = WindowManager.shared.windows[windowID] else { break }
    window.unobserve()
    EventManager.shared.post(event: .windowDestroyed, object: window)
  default:
    break
  }
}
