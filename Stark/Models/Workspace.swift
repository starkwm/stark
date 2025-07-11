import AppKit

class Workspace: NSObject {
  static let shared = Workspace()

  private var activationPolicyObserved = [UInt32]()
  private var finishedLaunchingObserved = [UInt32]()

  override init() {
    super.init()

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(activeSpaceDidChange(_:)),
      name: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil
    )
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

    debug("adding observer for activation policy \(process)")
    activationPolicyObserved.append(process.psn.lowLongOfPSN)

    application.addObserver(
      Workspace.shared,
      forKeyPath: "activationPolicy",
      options: [.initial, .new],
      context: context
    )
  }

  func unobserveActivationPolicy(_ process: Process) {
    guard let application = process.application else { return }

    if activationPolicyObserved.contains(where: { $0 == process.psn.lowLongOfPSN }) {
      let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(process).toOpaque()

      debug("removing observer for activation policy \(process)")
      activationPolicyObserved.removeAll(where: { $0 == process.psn.lowLongOfPSN })
      application.removeObserver(Workspace.shared, forKeyPath: "activationPolicy", context: context)
    }
  }

  func isFinishedLaunching(_ process: Process) -> Bool {
    guard let application = process.application else { return false }

    return application.isFinishedLaunching
  }

  func observeFinishedLaunching(_ process: Process) {
    guard let application = process.application else { return }

    let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(process).toOpaque()

    debug("adding observer for finished launching \(process)")
    finishedLaunchingObserved.append(process.psn.lowLongOfPSN)
    application.addObserver(
      Workspace.shared,
      forKeyPath: "finishedLaunching",
      options: [.initial, .new],
      context: context
    )
  }

  func unobserveFinishedLaunching(_ process: Process) {
    guard let application = process.application else { return }

    if finishedLaunchingObserved.contains(where: { $0 == process.psn.lowLongOfPSN }) {
      let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(process).toOpaque()

      debug("removing observer for finished launching \(process)")
      finishedLaunchingObserved.removeAll(where: { $0 == process.psn.lowLongOfPSN })
      application.removeObserver(Workspace.shared, forKeyPath: "finishedLaunching", context: context)
    }
  }

  @objc
  func activeSpaceDidChange(_: Notification) {
    EventManager.shared.post(event: .spaceChanged, with: nil)
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
      guard let raw = change?[.newKey] as? Int,
        let result = NSApplication.ActivationPolicy(rawValue: raw)
      else { return }

      if result != process.policy {
        unobserveActivationPolicy(process)
        EventManager.shared.post(event: .applicationLaunched, with: process)
      }
    }

    if keyPath == "finishedLaunching" {
      guard let result = change?[.newKey] as? Bool else { return }

      if result {
        unobserveFinishedLaunching(process)
        EventManager.shared.post(event: .applicationLaunched, with: process)
      }
    }
  }
}
