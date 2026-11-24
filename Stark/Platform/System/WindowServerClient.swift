import AppKit
import Carbon
import CoreGraphics
import StarkSkyLight

final class WindowServerClient {
  static let live = WindowServerClient()

  @MainActor
  private var spaces: (any SpaceQuerying)?

  private init() {}

  @MainActor
  init(spaces: any SpaceQuerying) { self.spaces = spaces }

  func mainConnectionID() -> Int32 {
    SLSMainConnectionID()
  }

  func frontmostProcessID() -> pid_t? {
    var psn = ProcessSerialNumber()
    guard _SLPSGetFrontProcess(&psn) == noErr else { return nil }

    var pid = pid_t()
    guard GetProcessPID(&psn, &pid) == noErr else { return nil }

    return pid
  }

  func connectionID(for psn: ProcessSerialNumber, mainConnectionID: Int32) -> Int32? {
    var psn = psn
    var connectionID: Int32 = -1

    guard SLSGetConnectionIDForPSN(mainConnectionID, &psn, &connectionID) == .success else {
      return nil
    }

    return connectionID
  }

  func activeSpace() -> UInt64 {
    querySpaces(default: 0) { try $0.activeSpace()?.rawValue ?? 0 }
  }

  func currentSpace(screenID: String) -> UInt64 {
    querySpaces(default: 0) {
      try $0.currentSpace(for: DisplayID(rawValue: screenID))?.rawValue ?? 0
    }
  }

  func allSpaces() -> [StarkSkyLight.Space] {
    querySpaces(default: []) { try $0.snapshot().displays.flatMap(\.spaces) }
  }

  func screenID(forSpaceID spaceID: UInt64) -> String? {
    querySpaces(default: nil) {
      try $0.snapshot().displayID(containing: SpaceID(rawValue: spaceID))?.rawValue
    }
  }

  func spaceIDs(containing windowID: CGWindowID) -> [UInt64] {
    querySpaces(default: []) { try $0.spaceIDs(containing: windowID).map(\.rawValue) }
  }

  func spaceType(for spaceID: UInt64) -> SpaceType {
    querySpaces(default: .unknown) { SpaceType(try $0.spaceType(for: SpaceID(rawValue: spaceID))) }
  }

  func windowIdentifiers(
    connectionID: Int32,
    applicationConnectionID: Int32,
    spaceIDs: [UInt64]
  ) -> [CGWindowID] {
    let spaces = spaceIDs as CFArray
    let options: UInt32 = 0x7
    var setTags: UInt64 = 0
    var clearTags: UInt64 = 0

    let windows = SLSCopyWindowsWithOptionsAndTags(
      connectionID,
      UInt32(applicationConnectionID),
      spaces,
      options,
      &setTags,
      &clearTags
    )

    let query = SLSWindowQueryWindows(connectionID, windows, Int32(CFArrayGetCount(windows)))
    let iterator = SLSWindowQueryResultCopyWindows(query)

    var windowIDs = [CGWindowID]()

    while SLSWindowIteratorAdvance(iterator) {
      guard SLSWindowIteratorGetParentID(iterator) == 0 else { continue }

      let level = NSWindow.Level(rawValue: SLSWindowIteratorGetLevel(iterator))
      guard level == .normal || level == .floating || level == .modalPanel else { continue }

      let attributes = SLSWindowIteratorGetAttributes(iterator)
      let tags = SLSWindowIteratorGetTags(iterator)
      guard validWindow(attributes: attributes, tags: tags) else { continue }

      let id = SLSWindowIteratorGetWindowID(iterator)
      windowIDs.append(id)
    }

    return windowIDs
  }

  // JSExport methods are synchronous. SpaceQuerying requires the main actor.
  private func querySpaces<Value: Sendable>(
    default fallback: Value,
    _ query: @MainActor (any SpaceQuerying) throws -> Value
  ) -> Value {
    @MainActor
    func read() -> Value {
      if spaces == nil { spaces = try? SpaceClient() }
      guard let spaces else { return fallback }
      return (try? query(spaces)) ?? fallback
    }

    if Thread.isMainThread { return MainActor.assumeIsolated { read() } }
    return DispatchQueue.main.sync { read() }
  }

  private func validWindow(attributes: UInt64, tags: UInt64) -> Bool {
    if ((attributes & 0x2) != 0 || (tags & 0x400_0000_0000_0000) != 0)
      && (((tags & 0x1) != 0) || ((tags & 0x2) != 0 && (tags & 0x8000_0000) != 0))
    {
      return true
    }

    if (attributes == 0x0 || attributes == 0x1)
      && ((tags & 0x1000_0000_0000_0000) != 0 || (tags & 0x300_0000_0000_0000) != 0)
      && (((tags & 0x1) != 0) || ((tags & 0x2) != 0 && (tags & 0x8000_0000) != 0))
    {
      return true
    }

    return false
  }
}
