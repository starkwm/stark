import AppKit

public class AccessibilityHelper {
    public static func askForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]

        if AXIsProcessTrustedWithOptions(options) {
            return
        }

        NSApp.terminate(nil)
    }
}
