import AppKit

class Config {
    static let primaryConfigPaths: [String] = [
        "~/.stark.js",
        "~/.config/stark/stark.js",
        "~/Library/Application Support/Stark/stark.js",
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

    func createUnlessExists() {
        if FileManager.default.fileExists(atPath: primaryConfigPath) {
            return
        }

        guard let examplePath = Bundle.main.path(forResource: "JavaScript/stark-example", ofType: "js") else {
            fatalError("Could not find stark-example.js")
        }

        FileManager.default.createFile(atPath: primaryConfigPath,
                                       contents: try? Data(contentsOf: URL(fileURLWithPath: examplePath)),
                                       attributes: nil)
    }
}
