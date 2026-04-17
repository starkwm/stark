import Testing

@testable import Stark

@Suite
struct SpaceTypeTests {
  @Test(arguments: [
    (SpaceType.normal, "normal"),
    (SpaceType.fullscreen, "fullscreen"),
    (SpaceType.unknown, "unknown"),
  ])
  func exposesDescriptions(_ value: SpaceType, _ expected: String) {
    #expect(value.description == expected)
  }
}
