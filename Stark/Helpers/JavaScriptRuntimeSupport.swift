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

  func beginRecording() {
    queue.sync {
      recording = makeEmptyStorage()
    }
  }

  func withActive<T>(_ block: (Storage) -> T) -> T {
    queue.sync {
      block(active)
    }
  }

  func withRecording<T>(_ block: (Storage?) -> T) -> T {
    queue.sync {
      block(recording)
    }
  }

  func mutate<T>(_ block: (inout Storage, inout Storage?) -> T) -> T {
    queue.sync {
      block(&active, &recording)
    }
  }

  func commit() -> (previousActive: Storage, nextActive: Storage)? {
    queue.sync {
      guard let recording else { return nil }

      let previousActive = active
      active = recording
      self.recording = nil

      return (previousActive, active)
    }
  }

  func discard() -> Storage? {
    queue.sync {
      let discarded = recording
      recording = nil
      return discarded
    }
  }
}

enum JSCallbackInvoker {
  static func addManagedReference(for object: AnyObject, callback: JSValue, owner: Any) {
    callback.context.virtualMachine.addManagedReference(object, withOwner: owner)
  }

  static func removeManagedReference(for object: AnyObject, callback: JSManagedValue?, owner: Any) {
    guard let callback = callback?.value else { return }

    callback.context.virtualMachine.removeManagedReference(object, withOwner: owner)
  }

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
