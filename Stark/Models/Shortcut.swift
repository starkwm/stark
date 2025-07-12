import Foundation

public struct Shortcut {
  let identifier = UUID()

  var keyCode: UInt32?
  var modifierFlags: UInt32?

  var handler: (() -> Void)!

  init() {}
}
