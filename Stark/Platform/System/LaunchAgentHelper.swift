import Foundation

enum LaunchAgentHelper {
  private static func libraryDirectory() -> URL? {
    try? FileManager.default.url(
      for: .libraryDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: false
    )
  }

  private static func isReachable(_ url: URL) -> Bool {
    (url as NSURL).checkResourceIsReachableAndReturnError(nil)
  }

  static func launchAgentDirectory() -> URL? {
    libraryDirectory()?.appendingPathComponent("LaunchAgents")
  }

  static func launchAgentFile() -> URL? {
    guard
      let launchAgentDirectory = launchAgentDirectory(),
      let bundleIdentifier = Bundle.main.bundleIdentifier
    else { return nil }

    return launchAgentDirectory.appendingPathComponent("\(bundleIdentifier).plist")
  }

  static func add() {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
      log("could not access launch agent plist file", level: .error)
      return
    }

    guard let launchAgentDirectory = launchAgentDirectory() else {
      log("could not access launch agent directory", level: .error)
      return
    }

    guard let launchAgentFile = launchAgentFile() else {
      log("could not access launch agent plist file", level: .error)
      return
    }

    if !isReachable(launchAgentDirectory) {
      try? FileManager.default.createDirectory(
        at: launchAgentDirectory,
        withIntermediateDirectories: false,
        attributes: nil
      )
    }

    guard let execPath = Bundle.main.executablePath else { return }

    let plist: [String: Any] = [
      "Label": bundleIdentifier,
      "Program": execPath,
      "RunAtLoad": true,
    ]

    (plist as NSDictionary).write(to: launchAgentFile, atomically: true)
  }

  static func remove() {
    guard let launchAgentFile = launchAgentFile() else { return }

    try? FileManager.default.removeItem(at: launchAgentFile)
  }

  static func enabled() -> Bool {
    guard let launchAgentFile = launchAgentFile() else { return false }

    return isReachable(launchAgentFile)
  }
}
