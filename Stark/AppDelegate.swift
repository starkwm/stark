import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem = StarkStatusItem()

  func applicationDidFinishLaunching(_: Notification) {
    if !askForAccessibilityIfNeeded() {
      log("accessibility permissions not granted", level: .error)
      return
    }

    if !ProcessManager.shared.begin() {
      log("could not start process manager", level: .error)
      return
    }

    WindowManager.shared.begin()

    if !ConfigManager.shared.start() {
      log("could not start config manager", level: .error)
      return
    }

    statusItem.setup()
  }

  func applicationWillTerminate(_: Notification) {
    ConfigManager.shared.stop()
  }

  private func askForAccessibilityIfNeeded() -> Bool {
    let options = ["kAXTrustedCheckOptionPrompt": true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary?)
  }
}
