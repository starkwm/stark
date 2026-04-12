import ApplicationServices

final class AccessibilityClient {
  static let live = AccessibilityClient()

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

  func focusedWindowElement(for element: AXUIElement) -> AXUIElement? {
    var value: AnyObject?

    guard
      AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value)
        == .success,
      let value
    else {
      return nil
    }

    return (value as! AXUIElement)
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

  func windowID(for element: AXUIElement) -> CGWindowID {
    if Thread.isMainThread {
      return unsafeWindowID(for: element)
    }

    return DispatchQueue.main.sync {
      unsafeWindowID(for: element)
    }
  }

  func processID(for element: AXUIElement) -> pid_t? {
    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else { return nil }
    return pid
  }

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

  private func unsafeWindowID(for element: AXUIElement) -> CGWindowID {
    var identifier: CGWindowID = 0
    let result: ApplicationServices.AXError = _AXUIElementGetWindow(element, &identifier)

    guard result == .success else { return 0 }

    return identifier
  }
}
