import Foundation

open class LaunchAgentHelper {
    fileprivate static var launchAgentDirectory: URL? {
        let libDir = try? FileManager.default
            .url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

        return libDir?.appendingPathComponent("LaunchAgents") ?? nil
    }

    fileprivate static var launchAgentFile: URL? {
        return launchAgentDirectory?.appendingPathComponent("co.rustyrobots.Stark.plist") ?? nil
    }

    open static func add() -> Bool {
        guard let launchAgentDirectory = launchAgentDirectory else {
            LogHelper.log(message: "Could not access launch agent directory")
            return false
        }

        guard let launchAgentFile = launchAgentFile else {
            LogHelper.log(message: "Could not access launch agent file")
            return false
        }

        if (launchAgentDirectory as NSURL).checkResourceIsReachableAndReturnError(nil) == false {
            let _ = try? FileManager.default
                .createDirectory(at: launchAgentDirectory, withIntermediateDirectories: false, attributes: nil)
        }

        guard let execPath = Bundle.main.executablePath else {
            return false
        }

        let plist: NSDictionary = [
            "Label": "co.rustyrobots.Stark",
            "Program": execPath,
            "RunAtLoad": true,
        ]

        plist.write(to: launchAgentFile, atomically: true)

        return true
    }

    open static func remove() {
        let _ = try? FileManager.default
            .removeItem(at: launchAgentFile!)
    }

    open static func enabled() -> Bool {
        let reachable = (launchAgentFile as NSURL?)?.checkResourceIsReachableAndReturnError(nil)
        return reachable ?? false
    }
}
