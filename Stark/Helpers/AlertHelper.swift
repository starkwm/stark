import AppKit

public class AlertHelper {
    public static func showConfigDialog(configPath: String) {
        let alert = NSAlert()
        alert.messageText = "Created new Stark configuration file"
        alert.informativeText = "Would you like to view this configuration file?"
        alert.alertStyle = .InformationalAlertStyle

        alert.addButtonWithTitle("Yes")
        alert.addButtonWithTitle("No")

        switch alert.runModal() {
        case NSAlertFirstButtonReturn:
            let task = NSTask()
            task.launchPath = "/usr/bin/open"
            task.arguments = [configPath]
            task.launch()
        default:
            let msg = "Invalid alert button pressed"
            NSLog(msg)
            LogHelper.log(msg)
        }
    }
}