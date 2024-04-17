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
    NSWorkspace.shared.runningApplications.map { Application(pid: $0.processIdentifier) }
  }

  static func focused() -> Application? {
    return NSWorkspace.shared.frontmostApplication.map { app in
      Application(pid: app.processIdentifier)
    }
  }

  static func find(_ name: String) -> Application? {
    return NSWorkspace.shared.runningApplications.first { $0.localizedName == name }.map { app in
      Application(pid: app.processIdentifier)
    }
  }

  var name: String {
    app.localizedName ?? "nil"
  }

  var bundleID: String {
    app.bundleIdentifier ?? "nil"
  }

  var processID: pid_t {
    app.processIdentifier
  }

  var isFrontmost: Bool {
    app.isActive
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
    app.isTerminated
  }

  var connection: Int32 = -1
  var observer: AXObserver?

  private var app: NSRunningApplication

  private var element: AXUIElement
  private var observedNotifications = ApplicationNotifications(rawValue: 0)
  private var observing = false

  init(pid: pid_t) {
    self.element = AXUIElementCreateApplication(pid)
    self.app = NSRunningApplication(processIdentifier: pid)!
  }

  init(process: Process) {
    self.element = AXUIElementCreateApplication(process.pid)
    self.app = NSRunningApplication(processIdentifier: process.pid)!

    SLSGetConnectionIDForPSN(Space.connection, &process.psn, &self.connection)
  }

  deinit {
    Logger.main.debug("destroying application \(self)")
  }

  func windows() -> [Window] {
    var values: AnyObject?

    if AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &values) != .success {
      return []
    }

    guard let windows = values as? [AXUIElement] else {
      return []
    }

    return windows.map { Window(element: $0) }
  }

  func activate() -> Bool {
    app.activate(options: .activateAllWindows)
  }

  func focus() -> Bool {
    app.activate(options: [])
  }

  func show() -> Bool {
    app.unhide()
  }

  func hide() -> Bool {
    app.hide()
  }

  func terminate() -> Bool {
    app.terminate()
  }

  func observe() -> Bool {
    if AXObserverCreate(app.processIdentifier, accessibilityObserverCallback, &observer) == .success {
      guard let observer = observer else {
        return false
      }

      let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(self).toOpaque()

      for (idx, notification) in applicationNotifications.enumerated() {
        let result = AXObserverAddNotification(observer, element, notification as CFString, context)

        if result == .success || result == .notificationAlreadyRegistered {
          observedNotifications.insert(ApplicationNotifications(rawValue: 1 << idx))
        } else {
          Logger.main.debug("notification \(notification) not added \(self)")
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
  case kAXTitleChangedNotification:
    EventManager.shared.post(event: .windowTitleChanged, object: Window.id(for: element))
  case kAXWindowMiniaturizedNotification:
    let window = Unmanaged<Window>.fromOpaque(context).takeUnretainedValue()
    EventManager.shared.post(event: .windowMinimized, object: window)
  case kAXWindowDeminiaturizedNotification:
    let window = Unmanaged<Window>.fromOpaque(context).takeUnretainedValue()
    EventManager.shared.post(event: .windowDeminimized, object: window)
  case kAXUIElementDestroyedNotification:
    let window = Unmanaged<Window>.fromOpaque(context).takeUnretainedValue()
    window.unobserve()
    EventManager.shared.post(event: .windowDestroyed, object: window)
  default:
    break
  }
}
