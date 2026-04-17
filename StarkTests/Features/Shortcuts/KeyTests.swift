import Carbon
import Testing

@testable import Stark

@Suite
struct KeyTests {
  @Test
  func resolvesFixedKeyAliases() {
    #expect(Key.resolve("return").keyCode == UInt32(kVK_Return))
    #expect(Key.resolve("enter").keyCode == UInt32(kVK_Return))
    #expect(Key.resolve("escape").keyCode == UInt32(kVK_Escape))
    #expect(Key.resolve("esc").keyCode == UInt32(kVK_Escape))
    #expect(Key.resolve("dash").keyCode == UInt32(kVK_ANSI_Minus))
    #expect(Key.resolve("minus").keyCode == UInt32(kVK_ANSI_Minus))
  }

  @Test
  func usesCaseInsensitiveLookup() {
    #expect(Key.resolve("RETURN").keyCode == UInt32(kVK_Return))
    #expect(Key.resolve("BaCkTiCk").keyCode == UInt32(kVK_ANSI_Grave))
  }

  @Test
  func specialKeysInjectFnLikeSkbd() {
    #expect(Key.resolve("left").keyCode == UInt32(kVK_LeftArrow))
    #expect(Key.resolve("left").modifiers == [.fn])
    #expect(Key.resolve("delete").keyCode == UInt32(kVK_ForwardDelete))
    #expect(Key.resolve("delete").modifiers == [.fn])
    #expect(Key.resolve("f12").keyCode == UInt32(kVK_F12))
    #expect(Key.resolve("f12").modifiers == [.fn])
  }

  @Test
  func nonSpecialKeysDoNotInjectFn() {
    #expect(Key.resolve("return").modifiers.isEmpty)
    #expect(Key.resolve("space").modifiers.isEmpty)
    #expect(Key.resolve("backtick").modifiers.isEmpty)
  }

  @Test
  func returnsZeroForUnknownKeys() {
    let resolvedKey = Key.resolve("not-a-real-key")

    #expect(resolvedKey.keyCode == 0)
    #expect(resolvedKey.modifiers.isEmpty)
  }
}
