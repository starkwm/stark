import ApplicationServices
import CoreGraphics
import Foundation

enum AccessibilityHelper {
  static func stringAttribute(
    for element: AXUIElement,
    attribute: String
  ) -> String? {
    var value: AnyObject?

    guard
      AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
      let result = value as? String
    else {
      return nil
    }

    return result
  }

  static func boolAttribute(
    for element: AXUIElement,
    attribute: String
  ) -> Bool? {
    var value: AnyObject?

    guard
      AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
      let number = value as? NSNumber
    else {
      return nil
    }

    return number.boolValue
  }

  static func pointAttribute(
    for element: AXUIElement,
    attribute: String
  ) -> CGPoint? {
    var value: AnyObject?
    var point = CGPoint.zero

    guard
      AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
      AXValueGetValue(value as! AXValue, AXValueType.cgPoint, &point)
    else {
      return nil
    }

    return point
  }

  static func sizeAttribute(
    for element: AXUIElement,
    attribute: String
  ) -> CGSize? {
    var value: AnyObject?
    var size = CGSize.zero

    guard
      AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
      AXValueGetValue(value as! AXValue, AXValueType.cgSize, &size)
    else {
      return nil
    }

    return size
  }

  @discardableResult
  static func setPoint(
    _ point: CGPoint,
    for element: AXUIElement,
    attribute: String
  ) -> Bool {
    var val = point

    guard let type = AXValueType(rawValue: kAXValueCGPointType) else { return false }
    guard let value = AXValueCreate(type, &val) else { return false }

    return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }

  @discardableResult
  static func setSize(
    _ size: CGSize,
    for element: AXUIElement,
    attribute: String
  ) -> Bool {
    var val = size

    guard let type = AXValueType(rawValue: kAXValueCGSizeType) else { return false }
    guard let value = AXValueCreate(type, &val) else { return false }

    return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }
}
