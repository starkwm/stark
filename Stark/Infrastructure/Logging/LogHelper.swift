import Foundation

struct LogFileSystem {
  var homeDirectory: () -> String
  var append: (URL, Data) -> Bool
  var write: (URL, Data) -> Void

  static let live = LogFileSystem(
    homeDirectory: { NSHomeDirectory() },
    append: { url, data in
      guard let handle = try? FileHandle(forWritingTo: url) else { return false }

      handle.seekToEndOfFile()
      handle.write(data)
      handle.closeFile()
      return true
    },
    write: { url, data in
      try? data.write(to: url)
    }
  )
}

struct LogHelper: TextOutputStream {
  let fileSystem: LogFileSystem

  /// Creates a logger that writes to the configured file system abstraction.
  init(fileSystem: LogFileSystem = .live) {
    self.fileSystem = fileSystem
  }

  /// Appends a log line to `~/.stark.log`, creating the file if necessary.
  func write(_ string: String) {
    let dir = URL(fileURLWithPath: fileSystem.homeDirectory())
    let file = dir.appendingPathComponent(".stark.log")
    let data = string.data(using: .utf8)!

    if !fileSystem.append(file, data) {
      fileSystem.write(file, data)
    }
  }
}

var logger = LogHelper()
var logDateProvider: () -> String = { Date().ISO8601Format() }
var logEnabledProvider: () -> Bool = { UserDefaults.standard.bool(forKey: "enableLogging") }
var logConsoleWriter: (String) -> Void = { print($0) }

enum LogLevel: String {
  case debug = "DEBUG"
  case info = "INFO"
  case warn = "WARN"
  case error = "ERROR"
}

/// Formats a log entry and writes it either to disk or the console based on user settings.
func log(_ message: @autoclosure () -> String, level: LogLevel = .debug) {
  let now = logDateProvider()
  let text = "\(now) \(level.rawValue): \(message())"

  if logEnabledProvider() {
    print(text, to: &logger)
  } else {
    logConsoleWriter(text)
  }
}
