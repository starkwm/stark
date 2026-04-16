import Testing

@testable import Stark

@Suite struct KeymapRegistryTests {
  @Test func retainsConfiguredShortcutManager() {
    let (registry, shortcutManagerID) = makeConfiguredRegistry()

    #expect(ObjectIdentifier(registry.shortcutManager) == shortcutManagerID)
  }

  private func makeConfiguredRegistry() -> (KeymapRegistry, ObjectIdentifier) {
    let registry = KeymapRegistry()
    let shortcutManager = ShortcutManager()

    registry.configure(shortcutManager: shortcutManager)

    return (registry, ObjectIdentifier(shortcutManager))
  }
}
