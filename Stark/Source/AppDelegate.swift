import Alicia
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  var config: Config
  var context: Context
  var statusItem: StarkStatusItem

  override init() {
    config = Config()
    context = Context(config: config)
    statusItem = StarkStatusItem(context: context)
  }

  func applicationDidFinishLaunching(_: Notification) {
    askForAccessibilityIfNeeded()
    context.setup()
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
