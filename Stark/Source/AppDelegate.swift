import Alicia
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  let statusItem = StarkStatusItem()

  func applicationDidFinishLaunching(_: Notification) {
    askForAccessibilityIfNeeded()
    statusItem.setup()
  }

  func applicationWillTerminate(_: Notification) {
    Alicia.stop()
  }

  func askForAccessibilityIfNeeded() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    AXIsProcessTrustedWithOptions(options as CFDictionary?)
  }
}
