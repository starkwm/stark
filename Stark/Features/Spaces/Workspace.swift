import AppKit

struct WorkspaceEnvironment {
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

  var addActiveSpaceObserver: (Workspace) -> Void
  var addObserver: (Workspace, Process, String, UnsafeMutableRawPointer?) -> Void
  var removeObserver: (Workspace, Process, String, UnsafeMutableRawPointer?) -> Void
  var postEvent: (RuntimeEvent) -> Void
}

class Workspace: NSObject {
  static let shared = Workspace()

  var activationPolicyObservedForTesting: [UInt32] {
    activationPolicyObservations.processIDs
  }

  var finishedLaunchingObservedForTesting: [UInt32] {
    finishedLaunchingObservations.processIDs
  }

  private let environment: WorkspaceEnvironment
  private let activationPolicyObservations = ProcessObservationRegistry(
    kind: .activationPolicy
  )
  private let finishedLaunchingObservations = ProcessObservationRegistry(
    kind: .finishedLaunching
  )

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
    observe(process, registry: activationPolicyObservations)
  }

  func unobserveActivationPolicy(_ process: Process) {
    unobserve(process, registry: activationPolicyObservations)
  }

  func isFinishedLaunching(_ process: Process) -> Bool {
    guard let application = process.application else { return false }

    return application.isFinishedLaunching
  }

  func observeFinishedLaunching(_ process: Process) {
    observe(process, registry: finishedLaunchingObservations)
  }

  func unobserveFinishedLaunching(_ process: Process) {
    unobserve(process, registry: finishedLaunchingObservations)
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
    guard let context else { return }

    let process = Unmanaged<Process>.fromOpaque(context).takeUnretainedValue()
    guard let registry = registry(for: keyPath) else { return }
    guard registry.kind.shouldRelaunch(process: process, change: change) else { return }

    unobserve(process, registry: registry)
    environment.postEvent(.application(.launched(process)))
  }

  private func observe(_ process: Process, registry: ProcessObservationRegistry) {
    guard process.application != nil else { return }

    let token = registry.register(process)

    environment.addObserver(self, process, token.keyPath, token.context)
  }

  private func unobserve(_ process: Process, registry: ProcessObservationRegistry) {
    guard process.application != nil else { return }
    guard let token = registry.unregister(process) else { return }

    environment.removeObserver(self, process, token.keyPath, token.context)
  }

  private func registry(for keyPath: String?) -> ProcessObservationRegistry? {
    switch keyPath {
    case activationPolicyObservations.kind.keyPath:
      activationPolicyObservations
    case finishedLaunchingObservations.kind.keyPath:
      finishedLaunchingObservations
    default:
      nil
    }
  }
}

private struct ProcessObservationToken {
  let keyPath: String
  let context: UnsafeMutableRawPointer?
  let processID: UInt32
}

private enum ProcessObservationKind {
  case activationPolicy
  case finishedLaunching

  var keyPath: String {
    switch self {
    case .activationPolicy:
      "activationPolicy"
    case .finishedLaunching:
      "finishedLaunching"
    }
  }

  func shouldRelaunch(process: Process, change: [NSKeyValueChangeKey: Any]?) -> Bool {
    switch self {
    case .activationPolicy:
      guard
        let raw = change?[.newKey] as? Int,
        let result = NSApplication.ActivationPolicy(rawValue: raw)
      else { return false }

      return result != process.policy
    case .finishedLaunching:
      guard let result = change?[.newKey] as? Bool else { return false }
      return result
    }
  }
}

private final class ProcessObservationRegistry {
  let kind: ProcessObservationKind

  var processIDs: [UInt32] {
    tokens.keys.sorted()
  }

  private var tokens = [UInt32: ProcessObservationToken]()

  init(kind: ProcessObservationKind) {
    self.kind = kind
  }

  func register(_ process: Process) -> ProcessObservationToken {
    if let existing = tokens[process.psn.lowLongOfPSN] {
      return existing
    }

    let token = ProcessObservationToken(
      keyPath: kind.keyPath,
      context: Unmanaged.passUnretained(process).toOpaque(),
      processID: process.psn.lowLongOfPSN
    )

    tokens[token.processID] = token

    return token
  }

  func unregister(_ process: Process) -> ProcessObservationToken? {
    tokens.removeValue(forKey: process.psn.lowLongOfPSN)
  }
}
