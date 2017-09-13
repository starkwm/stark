import AppKit

open class Config {
    fileprivate static let primaryConfigPaths: [String] = [
        "~/.stark.js",
        "~/Library/Application Support/Stark/stark.js",
        "~/.config/stark/stark.js",
    ]

    open let primaryConfigPath = Config.resolvePrimaryConfigPath()

    fileprivate static func resolvePrimaryConfigPath() -> String {
        for configPath in primaryConfigPaths {
            let resolvedConfigPath = (configPath as NSString).resolvingSymlinksInPath

            if FileManager.default.fileExists(atPath: resolvedConfigPath) {
                return resolvedConfigPath
            }
        }

        return (primaryConfigPaths.first! as NSString).resolvingSymlinksInPath
    }

    open func createUnlessExists(path: String) {
        if FileManager.default.fileExists(atPath: primaryConfigPath) {
            return
        }

        guard let example = Bundle.main.path(forResource: "stark-example", ofType: "js") else {
            return
        }

        if !FileManager.default.createFile(atPath: path, contents: try? Data(contentsOf: URL(fileURLWithPath: example)), attributes: nil) {
            LogHelper.log(message: String(format: "Unable to create configuration file: %@", path))
            return
        }

        if AlertHelper.showConfigDialog(configPath: path) == NSApplication.ModalResponse.alertFirstButtonReturn {
            edit()
        }
    }

    open func edit() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [primaryConfigPath]

        task.standardOutput = nil
        task.standardError = nil

        task.launch()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            let description = String(format: "There was a problem opening %@ as there is not an application available to open it.\n\nPlease edit this file manually.", primaryConfigPath)
            AlertHelper.show(message: "Unable to open the configuration file", description: description)
        }
    }
}
