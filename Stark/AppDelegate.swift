import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
  var config: Config
  var statusItem: StarkStatusItem

  override init() {
    self.config = Config()
    self.statusItem = StarkStatusItem(config: config)
  }

  func applicationDidFinishLaunching(_: Notification) {
    if !askForAccessibilityIfNeeded() {
      return
    }

    if !ProcessManager.shared.begin() {
      error("could not start process manager")
      return
    }

    WindowManager.shared.begin()

    statusItem.setup()
    config.execute()

    ShortcutManager.start()
  }

  func applicationWillTerminate(_: Notification) {
    ShortcutManager.stop()
  }

  private func askForAccessibilityIfNeeded() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary?)
  }
}
