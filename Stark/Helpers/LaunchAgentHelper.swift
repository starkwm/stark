import Foundation

enum LaunchAgentHelper {
  private static var launchAgentDirectory: URL? {
    let libDir = try? FileManager.default.url(
      for: .libraryDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: false
    )

    return libDir?.appendingPathComponent("LaunchAgents")
  }

  private static var launchAgentFile: URL? {
    launchAgentDirectory?.appendingPathComponent("\(Bundle.main.bundleIdentifier!).plist")
  }

  static func add() {
    guard let launchAgentDirectory else {
      log("could not access launch agent directory", level: .error)
      return
    }

    guard let launchAgentFile else {
      log("could not access launch agent plist file", level: .error)
      return
    }

    if (launchAgentDirectory as NSURL).checkResourceIsReachableAndReturnError(nil) == false {
      try? FileManager.default.createDirectory(
        at: launchAgentDirectory,
        withIntermediateDirectories: false,
        attributes: nil
      )
    }

    guard let execPath = Bundle.main.executablePath else { return }

    let plist: NSDictionary = [
      "Label": Bundle.main.bundleIdentifier!,
      "Program": execPath,
      "RunAtLoad": true,
    ]

    plist.write(to: launchAgentFile, atomically: true)
  }

  static func remove() {
    try? FileManager.default.removeItem(at: launchAgentFile!)
  }

  static func enabled() -> Bool {
    let reachable = (launchAgentFile as NSURL?)?.checkResourceIsReachableAndReturnError(nil)

    return reachable ?? false
  }
}
