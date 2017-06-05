import AppKit

open class AlertHelper {
    open static func showConfigDialog(configPath _: String) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "Created new Stark configuration file"
        alert.informativeText = "Would you like to view this configuration file?"
        alert.alertStyle = .informational

        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")

        return alert.runModal()
    }

    open static func show(message: String, description: String? = nil, error: NSError? = nil) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = description ?? (error?.localizedDescription ?? "")
        alert.alertStyle = .critical

        alert.runModal()
    }
}
