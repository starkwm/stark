import Foundation
import JavaScriptCore

final class StagedStorage<Storage> {
  private let queue: DispatchQueue
  private let makeEmptyStorage: () -> Storage

  private var active: Storage
  private var recording: Storage?

  init(active: Storage, queueLabel: String, makeEmptyStorage: @escaping () -> Storage) {
    self.active = active
    self.queue = DispatchQueue(label: queueLabel)
    self.makeEmptyStorage = makeEmptyStorage
  }

  /// Starts a staging session so mutations can be committed or discarded atomically.
  func beginRecording() {
    queue.sync {
      recording = makeEmptyStorage()
    }
  }

  /// Reads the active storage snapshot on the staging queue.
  func withActive<T>(_ block: (Storage) -> T) -> T {
    queue.sync {
      block(active)
    }
  }

  /// Reads the recording storage snapshot on the staging queue.
  func withRecording<T>(_ block: (Storage?) -> T) -> T {
    queue.sync {
      block(recording)
    }
  }

  /// Mutates active and recording storage together while holding the staging queue.
  func mutate<T>(_ block: (inout Storage, inout Storage?) -> T) -> T {
    queue.sync {
      block(&active, &recording)
    }
  }

  /// Promotes the recording storage to active storage and returns both snapshots.
  func commit() -> (previousActive: Storage, nextActive: Storage)? {
    queue.sync {
      guard let recording else { return nil }

      let previousActive = active
      active = recording
      self.recording = nil

      return (previousActive, active)
    }
  }

  /// Discards the recording storage and returns what was staged.
  func discard() -> Storage? {
    queue.sync {
      let discarded = recording
      recording = nil
      return discarded
    }
  }
}

enum JSCallbackInvoker {
  /// Retains a JS callback through the owning virtual machine for as long as Stark needs it.
  static func addManagedReference(for object: AnyObject, callback: JSValue, owner: Any) {
    callback.context.virtualMachine.addManagedReference(object, withOwner: owner)
  }

  /// Releases a previously retained JS callback from the owning virtual machine.
  static func removeManagedReference(for object: AnyObject, callback: JSManagedValue?, owner: Any) {
    guard let callback = callback?.value else { return }

    callback.context.virtualMachine.removeManagedReference(object, withOwner: owner)
  }

  /// Invokes a managed callback inside a fresh JS context that shares the same virtual machine.
  static func call(_ callback: JSManagedValue?, withArguments arguments: [Any]) {
    guard let callback = callback?.value else { return }

    guard let context = JSContext(virtualMachine: callback.context.virtualMachine) else { return }

    context.exceptionHandler = { _, err in
      log("unhandled javascript exception - \(String(describing: err))", level: .error)
    }

    let function = JSValue(object: callback, in: context)
    function?.call(withArguments: arguments)
  }
}
