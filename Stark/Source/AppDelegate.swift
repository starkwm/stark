import Alicia

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  var context: JavaScriptContext
  var statusItem: StarkStatusItem

  override init() {
    context = JavaScriptContext(configPath: ConfigHelper.resolvePrimaryPath())
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
