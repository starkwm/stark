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
