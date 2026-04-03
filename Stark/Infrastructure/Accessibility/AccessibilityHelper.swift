import ApplicationServices
import CoreGraphics
import Foundation

/// Helper enum providing utility methods for Accessibility API operations.
/// Wraps common AXUIElement attribute operations with type-safe getters and setters.
enum AccessibilityHelper {
  /// Retrieves a string attribute from an accessibility element.
  /// - Parameters:
  ///   - element: The AXUIElement to query
  ///   - attribute: The attribute name (e.g., kAXTitleAttribute)
  /// - Returns: The string value, or nil if not available
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

  /// Retrieves a boolean attribute from an accessibility element.
  /// - Parameters:
  ///   - element: The AXUIElement to query
  ///   - attribute: The attribute name (e.g., kAXMainAttribute)
  /// - Returns: The boolean value, or nil if not available
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

  /// Retrieves a CGPoint attribute from an accessibility element.
  /// - Parameters:
  ///   - element: The AXUIElement to query
  ///   - attribute: The attribute name (e.g., kAXPositionAttribute)
  /// - Returns: The point value, or nil if not available
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

  /// Retrieves a CGSize attribute from an accessibility element.
  /// - Parameters:
  ///   - element: The AXUIElement to query
  ///   - attribute: The attribute name (e.g., kAXSizeAttribute)
  /// - Returns: The size value, or nil if not available
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

  /// Sets a CGPoint attribute on an accessibility element.
  /// - Parameters:
  ///   - point: The point value to set
  ///   - element: The AXUIElement to modify
  ///   - attribute: The attribute name (e.g., kAXPositionAttribute)
  /// - Returns: true if successful
  @discardableResult
  static func setPoint(
    _ point: CGPoint,
    for element: AXUIElement,
    attribute: String
  ) -> Bool {
    var pointValue = point

    guard let type = AXValueType(rawValue: kAXValueCGPointType) else { return false }
    guard let value = AXValueCreate(type, &pointValue) else { return false }

    return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }

  /// Sets a CGSize attribute on an accessibility element.
  /// - Parameters:
  ///   - size: The size value to set
  ///   - element: The AXUIElement to modify
  ///   - attribute: The attribute name (e.g., kAXSizeAttribute)
  /// - Returns: true if successful
  @discardableResult
  static func setSize(
    _ size: CGSize,
    for element: AXUIElement,
    attribute: String
  ) -> Bool {
    var sizeValue = size

    guard let type = AXValueType(rawValue: kAXValueCGSizeType) else { return false }
    guard let value = AXValueCreate(type, &sizeValue) else { return false }

    return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }
}
