class Config {
  /// An array of primary locations of the configuration file.
  static let primaryPaths: [String] = [
    "~/.stark.js",
    "~/.config/stark/stark.js",
    "~/Library/Application Support/Stark/stark.js",
  ]

  /// Resolve the path of the configuration file to the first found location.
  static func resolvePrimaryPath() -> String {
    for configPath in primaryPaths {
      let resolvedConfigPath = (configPath as NSString).resolvingSymlinksInPath

      if FileManager.default.fileExists(atPath: resolvedConfigPath) {
        return resolvedConfigPath
      }
    }

    return (primaryPaths.first! as NSString).resolvingSymlinksInPath
  }

  /// The path the configuration file is resolved to.
  let primaryPath = Config.resolvePrimaryPath()
}
