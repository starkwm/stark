import AppKit

class Config {
    static let primaryConfigPaths: [String] = [
        "~/.stark.js",
        "~/Library/Application Support/Stark/stark.js",
        "~/.config/stark/stark.js",
    ]

    let primaryConfigPath = Config.resolvePrimaryConfigPath()

    static func resolvePrimaryConfigPath() -> String {
        for configPath in primaryConfigPaths {
            let resolvedConfigPath = (configPath as NSString).resolvingSymlinksInPath

            if FileManager.default.fileExists(atPath: resolvedConfigPath) {
                return resolvedConfigPath
            }
        }

        return (primaryConfigPaths.first! as NSString).resolvingSymlinksInPath
    }

    func createUnlessExists(path: String) {
        if FileManager.default.fileExists(atPath: primaryConfigPath) {
            return
        }

        guard let example = Bundle.main.path(forResource: "stark-example", ofType: "js") else {
            return
        }

        if !FileManager.default.createFile(atPath: path, contents: try? Data(contentsOf: URL(fileURLWithPath: example)), attributes: nil) {
            LogHelper.log(message: String(format: "Unable to create configuration file: %@", path))
        }
    }
}
