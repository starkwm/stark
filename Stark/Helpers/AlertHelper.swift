import AppKit

public class AlertHelper {
    public static func showConfigDialog(configPath: String) -> NSModalResponse {
        let alert = NSAlert()
        alert.messageText = "Created new Stark configuration file"
        alert.informativeText = "Would you like to view this configuration file?"
        alert.alertStyle = .Informational

        alert.addButtonWithTitle("Yes")
        alert.addButtonWithTitle("No")

        return alert.runModal()
    }

    public static func show(message: String, description: String? = nil, error: NSError? = nil) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = description ?? (error?.localizedDescription ?? "")
        alert.alertStyle = .Critical

        alert.runModal()
    }
}
