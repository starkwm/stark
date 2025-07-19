import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
  var config: Config
  var statusItem: StarkStatusItem

  override init() {
    config = Config()
    statusItem = StarkStatusItem(config: config)
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
    config.execute()

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
