import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusItem: StarkStatusItem

  override init() {
    statusItem = StarkStatusItem()
  }

  func applicationDidFinishLaunching(_: Notification) {
    if !askForAccessibilityIfNeeded() {
      return
    }

    if !ProcessManager.shared.begin() {
      log("could not start process manager", level: .error)
      return
    }

    WindowManager.shared.begin()

    statusItem.setup()

    if !ConfigManager.shared.start() {
      log("could not start config manager", level: .error)
    }

    ShortcutManager.start()
  }

  func applicationWillTerminate(_: Notification) {
    ShortcutManager.stop()
  }

  private func askForAccessibilityIfNeeded() -> Bool {
    let options = ["kAXTrustedCheckOptionPrompt": true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary?)
  }
}
