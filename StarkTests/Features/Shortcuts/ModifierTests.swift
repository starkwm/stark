import CoreGraphics
import Testing

@testable import Stark

@Suite struct ModifierTests {
  @Test func resolvesCanonicalModifiersAndIgnoresDuplicates() {
    let modifiers = Modifier.parse(["cmd", "alt", "SHIFT", "shift", "ctrl", "fn"])

    #expect(modifiers == [.cmd, .alt, .shift, .ctrl, .fn])
  }

  @Test func resolvesSidedModifiers() {
    let modifiers = Modifier.parse(["lcmd", "rshift", "lalt", "rctrl"])

    #expect(modifiers == [.lcmd, .rshift, .lalt, .rctrl])
  }

  @Test func rejectsRemovedAliases() {
    #expect(Modifier.parse(["option"]) == nil)
    #expect(Modifier.parse(["opt"]) == nil)
    #expect(Modifier.parse(["control"]) == nil)
    #expect(Modifier.parse(["command"]) == nil)
  }

  @Test func resolvesCompositeModifiers() {
    #expect(Modifier.parse(["meh"]) == [.alt, .ctrl, .shift])
    #expect(Modifier.parse(["hyper"]) == [.alt, .cmd, .ctrl, .shift])
  }

  @Test func normalizesDeviceSpecificEventFlags() {
    let flags = Modifier.from(
      CGEventFlags(
        rawValue: UInt64(
          NX_DEVICELCMDKEYMASK | NX_DEVICERALTKEYMASK | NX_DEVICELSHIFTKEYMASK
        )
      ).union([.maskCommand, .maskAlternate, .maskShift])
    )

    #expect(flags == [.lcmd, .ralt, .lshift])
  }

  @Test func fallsBackToGenericEventMasksWhenDeviceMasksAreAbsent() {
    let flags = Modifier.from([.maskCommand, .maskControl, .maskSecondaryFn])

    #expect(flags == [.cmd, .ctrl, .fn])
  }

  @Test func genericModifiersMatchEitherSide() {
    #expect(Modifier.compare([.cmd], [.lcmd]))
    #expect(Modifier.compare([.cmd], [.rcmd]))
    #expect(Modifier.compare([.ctrl], [.lctrl]))
    #expect(Modifier.compare([.alt], [.ralt]))
    #expect(Modifier.compare([.shift], [.rshift]))
  }

  @Test func sidedModifiersMatchOnlyTheirSide() {
    #expect(Modifier.compare([.lcmd], [.lcmd]))
    #expect(!Modifier.compare([.lcmd], [.rcmd]))
    #expect(!Modifier.compare([.lshift], [.shift]))
  }

  @Test func fnMustMatchExactly() {
    #expect(Modifier.compare([.fn], [.fn]))
    #expect(!Modifier.compare([.fn], []))
    #expect(!Modifier.compare([], [.fn]))
  }
}
