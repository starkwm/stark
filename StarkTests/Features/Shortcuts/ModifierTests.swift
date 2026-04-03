import Carbon
import Testing

@testable import Stark

@Suite struct ModifierTests {
  @Test func resolvesAliasesAndIgnoresUnknownValues() {
    let flags = Modifier.flags(for: ["cmd", "command", "alt", "option", "bogus"])

    #expect(flags == UInt32(cmdKey | optionKey))
  }

  @Test func deduplicatesRepeatedModifiers() {
    let flags = Modifier.flags(for: ["shift", "SHIFT", "shift"])

    #expect(flags == UInt32(shiftKey))
  }

  @Test func resolvesCompositeModifiers() {
    let meh = Modifier.flags(for: ["meh"])
    let hyper = Modifier.flags(for: ["hyper"])

    #expect(meh == UInt32(optionKey | shiftKey | controlKey))
    #expect(hyper == UInt32(cmdKey | optionKey | shiftKey | controlKey))
  }
}
