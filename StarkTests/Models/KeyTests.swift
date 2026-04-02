import Carbon
import Testing

@testable import Stark

@Suite struct KeyTests {
  @Test func resolvesFixedKeyAliases() {
    #expect(Key.code(for: "return") == UInt32(kVK_Return))
    #expect(Key.code(for: "enter") == UInt32(kVK_Return))
    #expect(Key.code(for: "escape") == UInt32(kVK_Escape))
    #expect(Key.code(for: "esc") == UInt32(kVK_Escape))
    #expect(Key.code(for: "dash") == UInt32(kVK_ANSI_Minus))
    #expect(Key.code(for: "minus") == UInt32(kVK_ANSI_Minus))
  }

  @Test func usesCaseInsensitiveLookup() {
    #expect(Key.code(for: "RETURN") == UInt32(kVK_Return))
    #expect(Key.code(for: "BaCkTiCk") == UInt32(kVK_ANSI_Grave))
  }

  @Test func returnsZeroForUnknownKeys() {
    #expect(Key.code(for: "not-a-real-key") == 0)
  }
}
