import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = StarkStatusItem()

    func applicationDidFinishLaunching(_: Notification) {
        askForAccessibilityIfNeeded()

        statusItem.setup()

        NotificationCenter.default.post(name: Notification.Name(rawValue: starkDidStartLaunch), object: self)
    }

    func askForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]

        if AXIsProcessTrustedWithOptions(options as CFDictionary?) {
            return
        }

        NSApp.terminate(nil)
    }
}
