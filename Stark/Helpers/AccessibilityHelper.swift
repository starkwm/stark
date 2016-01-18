import AppKit

class AccessibilityHelper {
    static func askForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]

        if AXIsProcessTrustedWithOptions(options) {
            return
        }

        NSApp.terminate(nil)
    }
}