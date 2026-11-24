import CoreGraphics
import StarkSkyLight
import Testing

@testable import Stark

@Suite
@MainActor
struct WindowServerClientTests {
  @Test
  func preservesDisplayOrderAndFirstScreenForSharedSpaces() {
    let server = WindowServerClient(spaces: Query())
    let spaces = server.allSpaces()
    #expect(spaces.map(\.id.rawValue) == [30, 10, 10, 20])
    #expect(
      spaces.map { Stark.SpaceType($0.type) } == [.normal, .fullscreen, .fullscreen, .unknown]
    )
    #expect(server.screenID(forSpaceID: 10) == "A")
    #expect(server.screenID(forSpaceID: 20) == "B")
    #expect(server.activeSpace() == 30)
    #expect(server.currentSpace(screenID: "B") == 20)
  }

  @Test
  func failedReadsKeepSynchronousScriptFallbacks() {
    let server = WindowServerClient(spaces: Query(unavailable: true))
    #expect(server.activeSpace() == 0)
    #expect(server.currentSpace(screenID: "B") == 0)
    #expect(server.allSpaces().isEmpty)
    #expect(server.screenID(forSpaceID: 10) == nil)
    #expect(server.spaceIDs(containing: 7).isEmpty)
    #expect(server.spaceType(for: 10) == .unknown)
  }
}

private struct Query: SpaceQuerying {
  var unavailable = false

  func snapshot() throws -> SpaceSnapshot {
    if unavailable { throw SkyLightError.malformedResponse("displays") }
    let shared = StarkSkyLight.Space(id: SpaceID(rawValue: 10), type: .fullscreen)
    let first = StarkSkyLight.Space(id: SpaceID(rawValue: 30), type: .desktop)
    let last = StarkSkyLight.Space(id: SpaceID(rawValue: 20), type: .unknown(9))
    return SpaceSnapshot(
      displays: [
        DisplaySpaces(id: DisplayID(rawValue: "A"), spaces: [first, shared], currentSpaceID: nil),
        DisplaySpaces(
          id: DisplayID(rawValue: "B"),
          spaces: [shared, last],
          currentSpaceID: last.id
        ),
      ],
      activeSpaceID: nil
    )
  }

  func activeSpace() throws -> SpaceID? { unavailable ? nil : SpaceID(rawValue: 30) }
  func currentSpace(for displayID: DisplayID) throws -> SpaceID? {
    if unavailable { throw SkyLightError.queryFailed("current") }
    return displayID.rawValue == "B" ? SpaceID(rawValue: 20) : nil
  }
  func spaceIDs(containing windowID: CGWindowID) throws -> [SpaceID] {
    throw SkyLightError.queryFailed("membership")
  }
  func spaceType(for spaceID: SpaceID) throws -> StarkSkyLight.SpaceType {
    throw SkyLightError.queryFailed("type")
  }
}
