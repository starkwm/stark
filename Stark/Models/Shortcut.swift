import Foundation

public struct Shortcut {
  public let identifier = UUID()

  public var keyCode: UInt32?
  public var modifierFlags: UInt32?

  public var handler: (() -> Void)!

  public init() {}
}
