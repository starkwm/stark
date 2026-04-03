import Carbon

final class ProcessClient {
  static let live = ProcessClient()

  /// Returns the process identifier of the system's current frontmost application.
  func frontmostProcessID() -> pid_t? {
    var psn = ProcessSerialNumber()
    guard _SLPSGetFrontProcess(&psn) == noErr else { return nil }

    var pid = pid_t()
    guard GetProcessPID(&psn, &pid) == noErr else { return nil }

    return pid
  }

  /// Resolves a SkyLight connection id for the given Carbon process serial number.
  func connectionID(for psn: ProcessSerialNumber, mainConnectionID: Int32) -> Int32? {
    var psn = psn
    var connectionID: Int32 = -1

    guard SLSGetConnectionIDForPSN(mainConnectionID, &psn, &connectionID) == .success else {
      return nil
    }

    return connectionID
  }
}
