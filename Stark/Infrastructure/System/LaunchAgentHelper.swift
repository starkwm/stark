import Foundation

struct LaunchAgentEnvironment {
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

  var libraryDirectory: () -> URL?
  var bundleIdentifier: () -> String?
  var executablePath: () -> String?
  var isReachable: (URL) -> Bool
  var createDirectory: (URL) -> Void
  var writePlist: ([String: Any], URL) -> Void
  var removeItem: (URL) -> Void
}

enum LaunchAgentHelper {
  private static var environment = LaunchAgentEnvironment.live

  static func launchAgentDirectory() -> URL? {
    environment.libraryDirectory()?.appendingPathComponent("LaunchAgents")
  }

  static func launchAgentFile() -> URL? {
    guard
      let launchAgentDirectory = launchAgentDirectory(),
      let bundleIdentifier = environment.bundleIdentifier()
    else { return nil }

    return launchAgentDirectory.appendingPathComponent("\(bundleIdentifier).plist")
  }

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

  static func remove() {
    guard let launchAgentFile = launchAgentFile() else { return }

    environment.removeItem(launchAgentFile)
  }

  static func enabled() -> Bool {
    guard let launchAgentFile = launchAgentFile() else { return false }

    return environment.isReachable(launchAgentFile)
  }

  static func useEnvironment(_ environment: LaunchAgentEnvironment) {
    Self.environment = environment
  }

  static func resetForTesting() {
    environment = .live
  }
}
