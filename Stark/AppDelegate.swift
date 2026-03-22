import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem = StarkStatusItem()

  func applicationDidFinishLaunching(_: Notification) {
    if !askForAccessibilityIfNeeded() {
      NSApplication.shared.terminate(nil)
      return
    }

    switch ProcessManager.shared.start() {
    case .success: break
    case .failure(let error):
      log("could not start process manager: \(error)", level: .error)
      return
    }

    WindowManager.shared.start()

    switch ConfigManager.shared.start() {
    case .success: break
    case .failure(let error):
      log("could not start config manager: \(error)", level: .error)
      return
    }

    statusItem.setup()
  }

  func applicationWillTerminate(_: Notification) {
    ConfigManager.shared.stop()
  }

  private func askForAccessibilityIfNeeded() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary?)
  }
}
