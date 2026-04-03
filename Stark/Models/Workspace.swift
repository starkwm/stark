import AppKit

struct WorkspaceEnvironment {
  var addActiveSpaceObserver: (Workspace) -> Void
  var addObserver: (Workspace, Process, String, UnsafeMutableRawPointer?) -> Void
  var removeObserver: (Workspace, Process, String, UnsafeMutableRawPointer?) -> Void
  var postEvent: (RuntimeEvent) -> Void

  static let live = WorkspaceEnvironment(
    addActiveSpaceObserver: { workspace in
      NSWorkspace.shared.notificationCenter.addObserver(
        workspace,
        selector: #selector(Workspace.activeSpaceDidChange(_:)),
        name: NSWorkspace.activeSpaceDidChangeNotification,
        object: nil
      )
    },
    addObserver: { workspace, process, keyPath, context in
      process.application?.addObserver(
        workspace,
        forKeyPath: keyPath,
        options: [.initial, .new],
        context: context
      )
    },
    removeObserver: { workspace, process, keyPath, context in
      process.application?.removeObserver(workspace, forKeyPath: keyPath, context: context)
    },
    postEvent: { event in
      EventManager.shared.post(event)
    }
  )
}

class Workspace: NSObject {
  static let shared = Workspace()

  private let environment: WorkspaceEnvironment
  private let activationPolicyObservations = ProcessObservationRegistry(keyPath: "activationPolicy")
  private let finishedLaunchingObservations = ProcessObservationRegistry(keyPath: "finishedLaunching")

  init(environment: WorkspaceEnvironment = .live) {
    self.environment = environment
    super.init()

    environment.addActiveSpaceObserver(self)
  }

  func isObservable(_ process: Process) -> Bool {
    guard let application = process.application else {
      process.policy = .prohibited
      return false
    }

    process.policy = application.activationPolicy

    return process.policy == .regular
  }

  func observeActivationPolicy(_ process: Process) {
    guard process.application != nil else { return }

    let token = activationPolicyObservations.register(process)

    log("adding observer for activation policy \(process)")
    environment.addObserver(self, process, token.keyPath, token.context)
  }

  func unobserveActivationPolicy(_ process: Process) {
    guard process.application != nil else { return }
    guard let token = activationPolicyObservations.unregister(process) else { return }

    log("removing observer for activation policy \(process)")
    environment.removeObserver(self, process, token.keyPath, token.context)
  }

  func isFinishedLaunching(_ process: Process) -> Bool {
    guard let application = process.application else { return false }

    return application.isFinishedLaunching
  }

  func observeFinishedLaunching(_ process: Process) {
    guard process.application != nil else { return }

    let token = finishedLaunchingObservations.register(process)

    log("adding observer for finished launching \(process)")
    environment.addObserver(self, process, token.keyPath, token.context)
  }

  func unobserveFinishedLaunching(_ process: Process) {
    guard process.application != nil else { return }
    guard let token = finishedLaunchingObservations.unregister(process) else { return }

    log("removing observer for finished launching \(process)")
    environment.removeObserver(self, process, token.keyPath, token.context)
  }

  @objc
  func activeSpaceDidChange(_: Notification) {
    environment.postEvent(.space(.changed(Space.active())))
  }

  override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    guard let context = context else { return }

    let process = Unmanaged<Process>.fromOpaque(context).takeUnretainedValue()

    if keyPath == activationPolicyObservations.keyPath {
      guard
        let raw = change?[.newKey] as? Int,
        let result = NSApplication.ActivationPolicy(rawValue: raw)
      else { return }

      if result != process.policy {
        unobserveActivationPolicy(process)
        environment.postEvent(.application(.launched(process)))
      }
    }

    if keyPath == finishedLaunchingObservations.keyPath {
      guard let result = change?[.newKey] as? Bool else { return }

      if result {
        unobserveFinishedLaunching(process)
        environment.postEvent(.application(.launched(process)))
      }
    }
  }

  var activationPolicyObservedForTesting: [UInt32] {
    activationPolicyObservations.processIDs
  }

  var finishedLaunchingObservedForTesting: [UInt32] {
    finishedLaunchingObservations.processIDs
  }
}

private struct ProcessObservationToken {
  let keyPath: String
  let context: UnsafeMutableRawPointer?
  let processID: UInt32
}

private final class ProcessObservationRegistry {
  let keyPath: String

  private var tokens = [UInt32: ProcessObservationToken]()

  init(keyPath: String) {
    self.keyPath = keyPath
  }

  func register(_ process: Process) -> ProcessObservationToken {
    if let existing = tokens[process.psn.lowLongOfPSN] {
      return existing
    }

    let token = ProcessObservationToken(
      keyPath: keyPath,
      context: Unmanaged.passUnretained(process).toOpaque(),
      processID: process.psn.lowLongOfPSN
    )

    tokens[token.processID] = token

    return token
  }

  func unregister(_ process: Process) -> ProcessObservationToken? {
    tokens.removeValue(forKey: process.psn.lowLongOfPSN)
  }

  var processIDs: [UInt32] {
    tokens.keys.sorted()
  }
}
