import Foundation

struct LogHelper: TextOutputStream {
  func write(_ string: String) {
    let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".stark.log")
    let data = Data(string.utf8)

    if let handle = try? FileHandle(forWritingTo: file) {
      handle.seekToEndOfFile()
      handle.write(data)
      handle.closeFile()
    } else {
      try? data.write(to: file)
    }
  }
}

private var logger = LogHelper()

enum LogLevel: String {
  case debug = "DEBUG"
  case info = "INFO"
  case warn = "WARN"
  case error = "ERROR"
}

func log(_ message: @autoclosure () -> String, level: LogLevel = .debug) {
  let now = Date().ISO8601Format()
  let text = "\(now) \(level.rawValue): \(message())"

  if UserDefaults.standard.bool(forKey: "enableLogging") {
    print(text, to: &logger)
  } else {
    print(text)
  }
}
