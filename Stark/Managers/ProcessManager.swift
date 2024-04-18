import Carbon
import OSLog

class ProcessManager {
  static let shared = ProcessManager()

  private(set) var processes = [UInt32: Process]()

  func begin() -> Bool {
    addRunningProcesses()

    let eventTypes = [
      EventTypeSpec(eventClass: OSType(kEventClassApplication), eventKind: OSType(kEventAppLaunched)),
      EventTypeSpec(eventClass: OSType(kEventClassApplication), eventKind: OSType(kEventAppTerminated)),
      EventTypeSpec(eventClass: OSType(kEventClassApplication), eventKind: OSType(kEventAppFrontSwitched)),
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
  }

  func add(_ process: Process) {
    processes[process.psn.lowLongOfPSN] = process
  }

  func remove(_ psn: ProcessSerialNumber) -> Process? {
    guard let process = processes.removeValue(forKey: psn.lowLongOfPSN) else {
      return nil
    }

    return process
  }

  func handleEvent(event: EventRef) -> OSStatus {
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
      guard let process = Process(psn: psn) else { return noErr }
      add(process)
      EventManager.shared.post(event: .applicationLaunched, object: process)
    case kEventAppTerminated:
      guard let process = remove(psn) else { break }
      process.terminated = true
      EventManager.shared.post(event: .applicationTerminated, object: process)
    case kEventAppFrontSwitched:
      guard let process = processes[psn.lowLongOfPSN] else { break }
      EventManager.shared.post(event: .applicationFrontSwitched, object: process)
    default:
      break
    }

    return noErr
  }

  private func addRunningProcesses() {
    var psn = ProcessSerialNumber()

    while GetNextProcess(&psn) == noErr {
      guard let process = Process(psn: psn) else {
        continue
      }

      add(process)
    }
  }
}

private func processEventHandler(_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?)
  -> OSStatus
{
  guard let event = event else { return noErr }

  return ProcessManager.shared.handleEvent(event: event)
}
