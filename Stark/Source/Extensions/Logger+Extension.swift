import OSLog

extension Logger {
  private static let subsystem = Bundle.main.bundleIdentifier!

  static let config = Logger(subsystem: subsystem, category: "Config")

  static let launchAgent = Logger(subsystem: subsystem, category: "LaunchAgentHelper")

  static let javascript = Logger(subsystem: subsystem, category: "JavaScript")
}
