import Foundation

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
