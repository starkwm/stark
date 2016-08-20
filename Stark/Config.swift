import AppKit

public class Config {
    private static let primaryConfigPaths: [String] = [
        "~/.stark.js",
        "~/Library/Application Support/Stark/stark.js",
        "~/.config/stark/stark.js",
    ]

    public let primaryConfigPath = Config.resolvePrimaryConfigPath()

    private static func resolvePrimaryConfigPath() -> String {
        for configPath in primaryConfigPaths {
            let resolvedConfigPath = (configPath as NSString).stringByResolvingSymlinksInPath

            if NSFileManager.defaultManager().fileExistsAtPath(resolvedConfigPath) {
                return resolvedConfigPath
            }
        }

        return (primaryConfigPaths.first! as NSString).stringByResolvingSymlinksInPath
    }

    public func createUnlessExists(path: String) {
        if NSFileManager.defaultManager().fileExistsAtPath(primaryConfigPath) {
            return
        }

        guard let example = NSBundle.mainBundle().pathForResource("stark-example", ofType: "js") else {
            return
        }

        if !NSFileManager.defaultManager().createFileAtPath(path, contents: NSData(contentsOfFile: example), attributes: nil) {
            LogHelper.log(String("Unable to create configuration file: %@", path))
            return
        }

        if AlertHelper.showConfigDialog(path) == NSAlertFirstButtonReturn {
            edit()
        }
    }

    public func edit() {
        let task = NSTask()
        task.launchPath = "/usr/bin/open"
        task.arguments = [primaryConfigPath]

        task.standardOutput = nil
        task.standardError = nil

        task.launch()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            let description = String(format: "There was a problem opening %@ as there is not an application available to open it.\n\nPlease edit this file manually.", primaryConfigPath)
            AlertHelper.show("Unable to open the configuration file", description: description)
        }
    }
}
