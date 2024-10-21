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

func debug(_ message: String) {
  print("\(Date()) debug: \(message)", to: &logger)
}

func error(_ message: String) {
  print("\(Date()) error: \(message)", to: &logger)
}
