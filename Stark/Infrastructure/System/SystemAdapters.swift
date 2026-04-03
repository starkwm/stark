import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

final class ProcessClient {
  static let live = ProcessClient()

  /// Returns the process identifier of the system's current frontmost application.
  func frontmostProcessID() -> pid_t? {
    var psn = ProcessSerialNumber()
    guard _SLPSGetFrontProcess(&psn) == noErr else { return nil }

    var pid = pid_t()
    guard GetProcessPID(&psn, &pid) == noErr else { return nil }

    return pid
  }

  /// Resolves a SkyLight connection id for the given Carbon process serial number.
  func connectionID(for psn: ProcessSerialNumber, mainConnectionID: Int32) -> Int32? {
    var psn = psn
    var connectionID: Int32 = -1

    guard SLSGetConnectionIDForPSN(mainConnectionID, &psn, &connectionID) == .success else {
      return nil
    }

    return connectionID
  }
}

final class AccessibilityClient {
  static let live = AccessibilityClient()

  /// Returns the AX application element for the given process id.
  func applicationElement(for processID: pid_t) -> AXUIElement {
    AXUIElementCreateApplication(processID)
  }

  func boolAttribute(for element: AXUIElement, attribute: String) -> Bool? {
    AccessibilityHelper.boolAttribute(for: element, attribute: attribute)
  }

  func stringAttribute(for element: AXUIElement, attribute: String) -> String? {
    AccessibilityHelper.stringAttribute(for: element, attribute: attribute)
  }

  func pointAttribute(for element: AXUIElement, attribute: String) -> CGPoint? {
    AccessibilityHelper.pointAttribute(for: element, attribute: attribute)
  }

  func sizeAttribute(for element: AXUIElement, attribute: String) -> CGSize? {
    AccessibilityHelper.sizeAttribute(for: element, attribute: attribute)
  }

  @discardableResult
  func setPoint(_ point: CGPoint, for element: AXUIElement, attribute: String) -> Bool {
    AccessibilityHelper.setPoint(point, for: element, attribute: attribute)
  }

  @discardableResult
  func setSize(_ size: CGSize, for element: AXUIElement, attribute: String) -> Bool {
    AccessibilityHelper.setSize(size, for: element, attribute: attribute)
  }

  @discardableResult
  func setAttributeValue(_ value: CFTypeRef, for element: AXUIElement, attribute: String) -> Bool {
    AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }

  /// Returns the AX window elements currently exposed by an application element.
  func windowElements(for element: AXUIElement) -> [AXUIElement] {
    var values: AnyObject?

    guard
      AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &values) == .success,
      let windows = values as? [AXUIElement]
    else {
      return []
    }

    return windows
  }

  /// Returns the currently focused AX window element for an application element.
  func focusedWindowElement(for element: AXUIElement) -> AXUIElement? {
    var value: AnyObject?

    guard
      AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value)
        == .success,
      let value
    else {
      return nil
    }

    return value as! AXUIElement
  }

  func subrole(for element: AXUIElement) -> String? {
    stringAttribute(for: element, attribute: kAXSubroleAttribute as String)
  }

  func isMainWindow(_ element: AXUIElement) -> Bool {
    boolAttribute(for: element, attribute: kAXMainAttribute as String) ?? false
  }

  func isWindow(_ element: AXUIElement) -> Bool {
    stringAttribute(for: element, attribute: kAXRoleAttribute as String) == kAXWindowRole
  }

  /// Resolves the Core Graphics window id for an AX window element.
  func windowID(for element: AXUIElement) -> CGWindowID {
    var identifier: CGWindowID = 0
    _AXUIElementGetWindow(element, &identifier)
    return identifier
  }

  /// Resolves the owning process id for an AX element.
  func processID(for element: AXUIElement) -> pid_t? {
    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else { return nil }
    return pid
  }

  /// Reads the Enhanced User Interface flag used by some apps to resist window manipulation.
  func enhancedUIEnabled(for element: AXUIElement, attribute: String) -> Bool {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

    if result == .success,
      let value,
      CFGetTypeID(value) == CFBooleanGetTypeID()
    {
      let boolValue = value as! CFBoolean
      return CFBooleanGetValue(boolValue)
    }

    return false
  }

  /// Creates an AX observer for a process and wraps the result in Stark's error type.
  func createObserver(processID: pid_t, callback: @escaping AXObserverCallback) -> Result<
    AXObserver, AXError
  > {
    var observer: AXObserver?
    let result = AXObserverCreate(processID, callback, &observer)

    guard result == .success, let observer else {
      return .failure(.observerCreationFailed)
    }

    return .success(observer)
  }

  func addNotification(
    observer: AXObserver,
    element: AXUIElement,
    notification: String,
    context: UnsafeMutableRawPointer?
  ) -> ApplicationServices.AXError {
    AXObserverAddNotification(observer, element, notification as CFString, context)
  }

  func removeNotification(observer: AXObserver, element: AXUIElement, notification: String) {
    AXObserverRemoveNotification(observer, element, notification as CFString)
  }
}

final class WindowServerClient {
  static let live = WindowServerClient()

  private let screenIDKey = "Display Identifier"
  private let spaceIDKey = "ManagedSpaceID"
  private let spacesKey = "Spaces"

  /// Returns the process-wide SkyLight connection id used for window server queries.
  func mainConnectionID() -> Int32 {
    SLSMainConnectionID()
  }

  /// Returns the currently active space identifier.
  func activeSpace(connectionID: Int32) -> UInt64 {
    SLSGetActiveSpace(connectionID)
  }

  /// Returns the space currently displayed on a specific screen.
  func currentSpace(connectionID: Int32, screenID: String) -> UInt64 {
    SLSManagedDisplayGetCurrentSpace(connectionID, screenID as CFString)
  }

  /// Returns every known space identifier across all managed displays.
  func allSpaceIDs(connectionID: Int32) -> [UInt64] {
    managedDisplaySpaces(connectionID: connectionID).flatMap { info -> [UInt64] in
      guard let spacesInfo = info[spacesKey] as? [[String: AnyObject]] else { return [] }
      return spacesInfo.compactMap { $0[spaceIDKey] as? UInt64 }
    }
  }

  /// Returns the display identifier currently associated with a given space.
  func screenID(forSpaceID spaceID: UInt64, connectionID: Int32) -> String? {
    for info in managedDisplaySpaces(connectionID: connectionID) {
      guard let screenID = info[screenIDKey] as? String,
        let spacesInfo = info[spacesKey] as? [[String: AnyObject]]
      else {
        continue
      }

      if spacesInfo.contains(where: { ($0[spaceIDKey] as? UInt64) == spaceID }) {
        return screenID
      }
    }

    return nil
  }

  /// Returns the ids of spaces that currently contain the given window.
  func spaceIDs(containing windowID: CGWindowID, connectionID: Int32) -> [UInt64] {
    let identifiers = SLSCopySpacesForWindows(connectionID, 0x7, [windowID] as CFArray) as NSArray
    return identifiers.compactMap { $0 as? UInt64 }
  }

  /// Resolves Stark's `SpaceType` from the raw SkyLight space type code.
  func spaceType(connectionID: Int32, spaceID: UInt64) -> SpaceType {
    SpaceType(rawValue: SLSSpaceGetType(connectionID, spaceID)) ?? .unknown
  }

  /// Returns top-level, user-manageable windows for an app across the provided spaces.
  func windowIdentifiers(
    connectionID: Int32,
    applicationConnectionID: Int32,
    spaceIDs: [UInt64]
  ) -> [CGWindowID] {
    let spaces = spaceIDs as CFArray
    let options: UInt32 = 0x7
    var setTags: UInt64 = 0
    var clearTags: UInt64 = 0

    let windows = SLSCopyWindowsWithOptionsAndTags(
      connectionID,
      UInt32(applicationConnectionID),
      spaces,
      options,
      &setTags,
      &clearTags
    )

    let query = SLSWindowQueryWindows(connectionID, windows, Int32(CFArrayGetCount(windows)))
    let iterator = SLSWindowQueryResultCopyWindows(query)

    var windowIDs = [CGWindowID]()

    while SLSWindowIteratorAdvance(iterator) {
      guard SLSWindowIteratorGetParentID(iterator) == 0 else { continue }

      let level = NSWindow.Level(rawValue: SLSWindowIteratorGetLevel(iterator))
      guard level == .normal || level == .floating || level == .modalPanel else { continue }

      let attributes = SLSWindowIteratorGetAttributes(iterator)
      let tags = SLSWindowIteratorGetTags(iterator)
      guard validWindow(attributes: attributes, tags: tags) else { continue }

      let id = SLSWindowIteratorGetWindowID(iterator)
      windowIDs.append(id)
    }

    return windowIDs
  }

  /// Reads the raw SkyLight managed display structure and normalizes it into dictionaries.
  private func managedDisplaySpaces(connectionID: Int32) -> [[String: AnyObject]] {
    let info = SLSCopyManagedDisplaySpaces(connectionID) as NSArray
    return info.compactMap { $0 as? [String: AnyObject] }
  }

  /// Filters SkyLight window metadata to the classes of windows Stark can actually manage.
  private func validWindow(attributes: UInt64, tags: UInt64) -> Bool {
    if ((attributes & 0x2) != 0 || (tags & 0x400_0000_0000_0000) != 0)
      && (((tags & 0x1) != 0) || ((tags & 0x2) != 0 && (tags & 0x8000_0000) != 0))
    {
      return true
    }

    if (attributes == 0x0 || attributes == 0x1)
      && ((tags & 0x1000_0000_0000_0000) != 0 || (tags & 0x300_0000_0000_0000) != 0)
      && (((tags & 0x1) != 0) || ((tags & 0x2) != 0 && (tags & 0x8000_0000) != 0))
    {
      return true
    }

    return false
  }
}
