import Carbon

struct ModifierGroup {
  static let groups: [ModifierGroup] = [
    .init(.alt, .lalt, .ralt, .maskAlternate, NX_DEVICELALTKEYMASK, NX_DEVICERALTKEYMASK),
    .init(.cmd, .lcmd, .rcmd, .maskCommand, NX_DEVICELCMDKEYMASK, NX_DEVICERCMDKEYMASK),
    .init(.ctrl, .lctrl, .rctrl, .maskControl, NX_DEVICELCTLKEYMASK, NX_DEVICERCTLKEYMASK),
    .init(.shift, .lshift, .rshift, .maskShift, NX_DEVICELSHIFTKEYMASK, NX_DEVICERSHIFTKEYMASK),
  ]

  let generic: Modifier
  let left: Modifier
  let right: Modifier
  let mask: CGEventFlags
  let leftMask: CGEventFlags
  let rightMask: CGEventFlags

  init(
    _ generic: Modifier,
    _ left: Modifier,
    _ right: Modifier,
    _ mask: CGEventFlags,
    _ leftMask: Int32,
    _ rightMask: Int32
  ) {
    self.generic = generic
    self.left = left
    self.right = right
    self.mask = mask
    self.leftMask = CGEventFlags(rawValue: UInt64(leftMask))
    self.rightMask = CGEventFlags(rawValue: UInt64(rightMask))
  }

  func from(_ eventFlags: CGEventFlags) -> Modifier {
    guard eventFlags.contains(mask) else { return [] }

    switch (eventFlags.contains(leftMask), eventFlags.contains(rightMask)) {
    case (true, false): return left
    case (false, true): return right
    case (true, true): return [left, right]
    default: return generic
    }
  }
}
