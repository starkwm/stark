import Foundation

final class KeymapRegistry {
  private final class ShortcutEnvironment {
    var manager: ShortcutManager?
  }

  var shortcutManager: ShortcutManager {
    if let manager = shortcutEnvironment.manager {
      return manager
    }

    let manager = ShortcutManager()
    shortcutEnvironment.manager = manager
    return manager
  }

  private let keymaps = StagedStorage<[String: Keymap]>(
    active: [:],
    queueLabel: "dev.tombell.stark.keymaps",
    makeEmptyStorage: { [:] }
  )
  private let shortcutEnvironment = ShortcutEnvironment()

  func configure(shortcutManager: ShortcutManager) {
    shortcutEnvironment.manager = shortcutManager
  }

  func beginRecording() {
    keymaps.beginRecording()
  }

  func commitRecording() -> (previousActive: [String: Keymap], nextActive: [String: Keymap])? {
    keymaps.commit()
  }

  func discardRecording() -> [String: Keymap]? {
    keymaps.discard()
  }

  func insert(_ keymap: Keymap) -> (previous: Keymap?, isRecording: Bool) {
    keymaps.mutate { keymaps, recordingKeymaps in
      if recordingKeymaps != nil {
        let previous = recordingKeymaps?.updateValue(keymap, forKey: keymap.id)
        return (previous, true)
      }

      let previous = keymaps.updateValue(keymap, forKey: keymap.id)
      return (previous, false)
    }
  }

  func remove(id: String) -> (keymap: Keymap?, isRecording: Bool) {
    keymaps.mutate { keymaps, recordingKeymaps in
      if recordingKeymaps != nil {
        let keymap = recordingKeymaps?.removeValue(forKey: id)
        return (keymap, true)
      }

      let keymap = keymaps.removeValue(forKey: id)
      return (keymap, false)
    }
  }

  func reset() -> (removed: [Keymap], isRecording: Bool) {
    keymaps.mutate { keymaps, recordingKeymaps in
      if recordingKeymaps != nil {
        let removed = recordingKeymaps.map { Array($0.values) } ?? []
        recordingKeymaps?.removeAll()
        return (removed, true)
      }

      let removed = Array(keymaps.values)
      keymaps.removeAll()
      return (removed, false)
    }
  }
}
