import Alicia

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  var config: Config
  var statusItem: StarkStatusItem

  override init() {
    config = Config()
    statusItem = StarkStatusItem(config: config)
  }

  func applicationDidFinishLaunching(_: Notification) {
    askForAccessibilityIfNeeded()
    config.execute()
    statusItem.setup()
  }

  func applicationWillTerminate(_: Notification) {
    Alicia.stop()
  }

  private func askForAccessibilityIfNeeded() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    AXIsProcessTrustedWithOptions(options as CFDictionary?)
  }
}
