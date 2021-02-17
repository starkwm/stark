import Foundation

enum LaunchAgentHelper {
    static var launchAgentDirectory: URL? {
        let libDir = try? FileManager.default.url(for: .libraryDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: false)

        return libDir?.appendingPathComponent("LaunchAgents")
    }

    static var launchAgentFile: URL? {
        return launchAgentDirectory?.appendingPathComponent("co.rustyrobots.Stark.plist")
    }

    static func add() {
        guard let launchAgentDirectory = launchAgentDirectory else {
            LogHelper.log(message: "Error: could not access launch agent directory")
            return
        }

        guard let launchAgentFile = launchAgentFile else {
            LogHelper.log(message: "Error: could not access launch agent file")
            return
        }

        if (launchAgentDirectory as NSURL).checkResourceIsReachableAndReturnError(nil) == false {
            _ = try? FileManager.default.createDirectory(at: launchAgentDirectory,
                                                         withIntermediateDirectories: false,
                                                         attributes: nil)
        }

        guard let execPath = Bundle.main.executablePath else {
            return
        }

        let plist: NSDictionary = [
            "Label": "co.rustyrobots.Stark",
            "Program": execPath,
            "RunAtLoad": true,
        ]

        plist.write(to: launchAgentFile, atomically: true)
    }

    static func remove() {
        _ = try? FileManager.default
            .removeItem(at: launchAgentFile!)
    }

    static func enabled() -> Bool {
        let reachable = (launchAgentFile as NSURL?)?.checkResourceIsReachableAndReturnError(nil)
        return reachable ?? false
    }
}
