import AppKit

class AlertHelper {
    static func show(message: String, description: String? = nil, error: NSError? = nil) {
        let alert = NSAlert()
        alert.messageText = "Stark: \(message)"
        alert.informativeText = description ?? (error?.localizedDescription ?? "")
        alert.alertStyle = .CriticalAlertStyle

        alert.runModal()
    }
}