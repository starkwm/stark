import AppKit

struct WorkspaceEnvironment {
  var addActiveSpaceObserver: (Workspace) -> Void
  var addObserver: (Workspace, Process, String, UnsafeMutableRawPointer?) -> Void
  var removeObserver: (Workspace, Process, String, UnsafeMutableRawPointer?) -> Void
  var postEvent: (EventType, Any?) -> Void

  static let live = WorkspaceEnvironment(
    addActiveSpaceObserver: { workspace in
      NSWorkspace.shared.notificationCenter.addObserver(
        workspace,
        selector: #selector(Workspace.activeSpaceDidChange(_:)),
        name: NSWorkspace.activeSpaceDidChangeNotification,
        object: nil
      )
    },
    addObserver: { _, process, keyPath, context in
      process.application?.addObserver(
        Workspace.shared,
        forKeyPath: keyPath,
        options: [.initial, .new],
        context: context
      )
    },
    removeObserver: { _, process, keyPath, context in
      process.application?.removeObserver(Workspace.shared, forKeyPath: keyPath, context: context)
    },
    postEvent: { event, object in
      EventManager.shared.post(event: event, with: object)
    }
  )
}

class Workspace: NSObject {
  static let shared = Workspace()

  private let environment: WorkspaceEnvironment
  private var activationPolicyObserved = [UInt32]()
  private var finishedLaunchingObserved = [UInt32]()

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
    guard let application = process.application else { return }

    let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(process).toOpaque()

    log("adding observer for activation policy \(process)")
    activationPolicyObserved.append(process.psn.lowLongOfPSN)

    environment.addObserver(self, process, "activationPolicy", context)
  }

  func unobserveActivationPolicy(_ process: Process) {
    guard let application = process.application else { return }

    if activationPolicyObserved.contains(where: { $0 == process.psn.lowLongOfPSN }) {
      let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(process).toOpaque()

      log("removing observer for activation policy \(process)")
      activationPolicyObserved.removeAll(where: { $0 == process.psn.lowLongOfPSN })
      environment.removeObserver(self, process, "activationPolicy", context)
    }
  }

  func isFinishedLaunching(_ process: Process) -> Bool {
    guard let application = process.application else { return false }

    return application.isFinishedLaunching
  }

  func observeFinishedLaunching(_ process: Process) {
    guard let application = process.application else { return }

    let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(process).toOpaque()

    log("adding observer for finished launching \(process)")
    finishedLaunchingObserved.append(process.psn.lowLongOfPSN)
    environment.addObserver(self, process, "finishedLaunching", context)
  }

  func unobserveFinishedLaunching(_ process: Process) {
    guard let application = process.application else { return }

    if finishedLaunchingObserved.contains(where: { $0 == process.psn.lowLongOfPSN }) {
      let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(process).toOpaque()

      log("removing observer for finished launching \(process)")
      finishedLaunchingObserved.removeAll(where: { $0 == process.psn.lowLongOfPSN })
      environment.removeObserver(self, process, "finishedLaunching", context)
    }
  }

  @objc
  func activeSpaceDidChange(_: Notification) {
    environment.postEvent(.spaceChanged, Space.active())
  }

  override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    guard let context = context else { return }

    let process = Unmanaged<Process>.fromOpaque(context).takeUnretainedValue()

    if keyPath == "activationPolicy" {
      guard
        let raw = change?[.newKey] as? Int,
        let result = NSApplication.ActivationPolicy(rawValue: raw)
      else { return }

      if result != process.policy {
        unobserveActivationPolicy(process)
        environment.postEvent(.applicationLaunched, process)
      }
    }

    if keyPath == "finishedLaunching" {
      guard let result = change?[.newKey] as? Bool else { return }

      if result {
        unobserveFinishedLaunching(process)
        environment.postEvent(.applicationLaunched, process)
      }
    }
  }

  var activationPolicyObservedForTesting: [UInt32] {
    activationPolicyObserved.sorted()
  }

  var finishedLaunchingObservedForTesting: [UInt32] {
    finishedLaunchingObserved.sorted()
  }
}
