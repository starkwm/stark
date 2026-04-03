import Carbon

/// Manages system process tracking and lifecycle events.
/// Uses Carbon Event APIs to monitor application launch/termination/switch events.
final class ProcessManager {
  static let shared = ProcessManager()

  private var processes = [UInt32: Process]()

  /// Starts monitoring system process events.
  /// - Returns: Success or failure with error details
  func start() -> Result<Void, AXError> {
    addRunningProcesses()

    let eventTypes = [
      EventTypeSpec(
        eventClass: OSType(kEventClassApplication),
        eventKind: OSType(kEventAppLaunched)
      ),
      EventTypeSpec(
        eventClass: OSType(kEventClassApplication),
        eventKind: OSType(kEventAppTerminated)
      ),
      EventTypeSpec(
        eventClass: OSType(kEventClassApplication),
        eventKind: OSType(kEventAppFrontSwitched)
      ),
    ]

    let result = InstallEventHandler(
      GetApplicationEventTarget(),
      processEventHandler,
      eventTypes.count,
      eventTypes,
      nil,
      nil
    )

    return result == noErr
      ? .success(()) : .failure(.accessFailed("failed to install event handler"))
  }

  func find(by psn: ProcessSerialNumber) -> Process? {
    processes[psn.lowLongOfPSN]
  }

  func all() -> [Process] {
    Array(processes.values)
  }

  private func addRunningProcesses() {
    var psn = ProcessSerialNumber()

    while GetNextProcess(&psn) == noErr {
      guard let process = Process(psn: psn) else { continue }
      processes[process.psn.lowLongOfPSN] = process
    }
  }
}

extension ProcessManager {
  func handle(event: EventRef) -> OSStatus {
    var psn = ProcessSerialNumber()

    GetEventParameter(
      event,
      UInt32(kEventParamProcessID),
      UInt32(typeProcessSerialNumber),
      nil,
      MemoryLayout<ProcessSerialNumber>.size,
      nil,
      &psn
    )

    switch Int(GetEventKind(event)) {
    case kEventAppLaunched:
      applicationLaunched(with: psn)

    case kEventAppTerminated:
      applicationTerminated(with: psn)

    case kEventAppFrontSwitched:
      applicationFrontSwitched(to: psn)

    default:
      break
    }

    return noErr
  }

  private func applicationLaunched(with psn: ProcessSerialNumber) {
    guard processes[psn.lowLongOfPSN] == nil else { return }
    guard let process = Process(psn: psn) else { return }

    processes[process.psn.lowLongOfPSN] = process

    EventManager.shared.post(.application(.launched(process)))
  }

  private func applicationTerminated(with psn: ProcessSerialNumber) {
    guard let process = processes[psn.lowLongOfPSN] else { return }

    processes.removeValue(forKey: psn.lowLongOfPSN)
    process.terminated = true

    EventManager.shared.post(.application(.terminated(process)))
  }

  private func applicationFrontSwitched(to psn: ProcessSerialNumber) {
    guard let process = processes[psn.lowLongOfPSN] else { return }

    EventManager.shared.post(.application(.frontSwitched(process)))
  }
}

private func processEventHandler(
  _: EventHandlerCallRef?,
  event: EventRef?,
  _: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let event = event else { return noErr }

  return ProcessManager.shared.handle(event: event)
}
