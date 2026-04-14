import AppKit
import Carbon
import CoreGraphics

final class WindowServerClient {
  static let live = WindowServerClient()

  private let screenIDKey = "Display Identifier"
  private let spaceIDKey = "ManagedSpaceID"
  private let spacesKey = "Spaces"

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

  func activeSpace(connectionID: Int32) -> UInt64 {
    SLSGetActiveSpace(connectionID)
  }

  func currentSpace(connectionID: Int32, screenID: String) -> UInt64 {
    SLSManagedDisplayGetCurrentSpace(connectionID, screenID as CFString)
  }

  func allSpaceIDs(connectionID: Int32) -> [UInt64] {
    managedDisplaySpaces(connectionID: connectionID).flatMap { info -> [UInt64] in
      guard let spacesInfo = info[spacesKey] as? [[String: AnyObject]] else { return [] }
      return spacesInfo.compactMap { $0[spaceIDKey] as? UInt64 }
    }
  }

  func screenID(forSpaceID spaceID: UInt64, connectionID: Int32) -> String? {
    for info in managedDisplaySpaces(connectionID: connectionID) {
      guard let screenID = info[screenIDKey] as? String,
        let spacesInfo = info[spacesKey] as? [[String: AnyObject]]
      else {
        continue
      }

      if spacesInfo.contains(where: { ($0[spaceIDKey] as? UInt64) == spaceID }) {
        return screenID
      }
    }

    return nil
  }

  func spaceIDs(containing windowID: CGWindowID, connectionID: Int32) -> [UInt64] {
    let identifiers = SLSCopySpacesForWindows(connectionID, 0x7, [windowID] as CFArray) as NSArray
    return identifiers.compactMap { $0 as? UInt64 }
  }

  func spaceType(connectionID: Int32, spaceID: UInt64) -> SpaceType {
    SpaceType(rawValue: SLSSpaceGetType(connectionID, spaceID)) ?? .unknown
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

  private func managedDisplaySpaces(connectionID: Int32) -> [[String: AnyObject]] {
    let info = SLSCopyManagedDisplaySpaces(connectionID) as NSArray
    return info.compactMap { $0 as? [String: AnyObject] }
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
