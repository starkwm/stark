import Foundation

struct LogHelper: TextOutputStream {
  func write(_ string: String) {
    let dir = URL(fileURLWithPath: NSHomeDirectory())
    let file = dir.appendingPathComponent(".stark.log")

    if let handle = try? FileHandle(forWritingTo: file) {
      handle.seekToEndOfFile()
      handle.write(string.data(using: .utf8)!)
      handle.closeFile()
    } else {
      try? string.data(using: .utf8)?.write(to: file)
    }
  }
}

var logger = LogHelper()

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
