import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var observer: RunningAppsObserver?

    let statusItem = StarkStatusItem()

    func applicationDidFinishLaunching(_: Notification) {
        observer = RunningAppsObserver()

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
