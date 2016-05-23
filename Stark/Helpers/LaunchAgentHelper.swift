import Foundation

public class LaunchAgentHelper {
    private static var launchAgentDirectory: NSURL? {
        let libDir = try? NSFileManager
            .defaultManager()
            .URLForDirectory(.LibraryDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)

        return libDir?.URLByAppendingPathComponent("LaunchAgents") ?? nil
    }

    private static var launchAgentFile: NSURL? {
        return launchAgentDirectory?.URLByAppendingPathComponent("co.rustyrobots.Stark.plist") ?? nil
    }

    public static func add() -> Bool {
        guard let launchAgentDirectory = launchAgentDirectory else {
            LogHelper.log("Could not access launch agent directory")
            return false
        }

        guard let launchAgentFile = launchAgentFile else {
            LogHelper.log("Could not access launch agent file")
            return false
        }

        if launchAgentDirectory.checkResourceIsReachableAndReturnError(nil) == false {
            let _ = try? NSFileManager
                .defaultManager()
                .createDirectoryAtURL(launchAgentDirectory, withIntermediateDirectories: false, attributes: nil)
        }

        guard let execPath = NSBundle.mainBundle().executablePath else {
            return false
        }

        let plist: NSDictionary = [
            "Label": "co.rustyrobots.Stark",
            "Program": execPath,
            "RunAtLoad": true
        ]

        plist.writeToURL(launchAgentFile, atomically: true)

        return true
    }

    public static func remove() {
        let _ = try? NSFileManager
            .defaultManager()
            .removeItemAtURL(launchAgentFile!)
    }

    public static func enabled() -> Bool {
        let reachable = launchAgentFile?.checkResourceIsReachableAndReturnError(nil)
        return reachable ?? false
    }
}