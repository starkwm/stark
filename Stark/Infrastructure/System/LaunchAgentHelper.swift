import Foundation

struct LaunchAgentEnvironment {
  var libraryDirectory: () -> URL?
  var bundleIdentifier: () -> String?
  var executablePath: () -> String?
  var isReachable: (URL) -> Bool
  var createDirectory: (URL) -> Void
  var writePlist: ([String: Any], URL) -> Void
  var removeItem: (URL) -> Void

  static let live = LaunchAgentEnvironment(
    libraryDirectory: {
      try? FileManager.default.url(
        for: .libraryDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      )
    },
    bundleIdentifier: { Bundle.main.bundleIdentifier },
    executablePath: { Bundle.main.executablePath },
    isReachable: { ($0 as NSURL).checkResourceIsReachableAndReturnError(nil) },
    createDirectory: {
      try? FileManager.default.createDirectory(
        at: $0,
        withIntermediateDirectories: false,
        attributes: nil
      )
    },
    writePlist: { plist, url in
      (plist as NSDictionary).write(to: url, atomically: true)
    },
    removeItem: { try? FileManager.default.removeItem(at: $0) }
  )
}

enum LaunchAgentHelper {
  private static var environment = LaunchAgentEnvironment.live

  /// Returns the per-user LaunchAgents directory used for login items.
  static func launchAgentDirectory() -> URL? {
    environment.libraryDirectory()?.appendingPathComponent("LaunchAgents")
  }

  /// Returns the plist path Stark uses for launch-at-login registration.
  static func launchAgentFile() -> URL? {
    guard
      let launchAgentDirectory = launchAgentDirectory(),
      let bundleIdentifier = environment.bundleIdentifier()
    else { return nil }

    return launchAgentDirectory.appendingPathComponent("\(bundleIdentifier).plist")
  }

  /// Creates or updates the launch agent plist so Stark starts at login.
  static func add() {
    guard let bundleIdentifier = environment.bundleIdentifier() else {
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

    if environment.isReachable(launchAgentDirectory) == false {
      environment.createDirectory(launchAgentDirectory)
    }

    guard let execPath = environment.executablePath() else { return }

    let plist: [String: Any] = [
      "Label": bundleIdentifier,
      "Program": execPath,
      "RunAtLoad": true,
    ]

    environment.writePlist(plist, launchAgentFile)
  }

  /// Removes Stark's launch agent plist if it exists.
  static func remove() {
    guard let launchAgentFile = launchAgentFile() else { return }

    environment.removeItem(launchAgentFile)
  }

  /// Returns whether the launch agent plist currently exists on disk.
  static func enabled() -> Bool {
    guard let launchAgentFile = launchAgentFile() else { return false }

    return environment.isReachable(launchAgentFile)
  }

  /// Replaces the live environment with a test double.
  static func useEnvironment(_ environment: LaunchAgentEnvironment) {
    Self.environment = environment
  }

  /// Restores the helper's environment to the live implementation.
  static func resetForTesting() {
    environment = .live
  }
}
