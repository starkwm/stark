/// Helper for logging messages to the log file.
enum LogHelper {
  /// Log a message to the log file.
  static func log(message: String) {
    NSLog("%@", message)

    let dir = URL(fileURLWithPath: NSHomeDirectory())
    let file = dir.appendingPathComponent(".stark.log")

    let formatter = DateFormatter()
    formatter.dateFormat = "[yyyy-MM-dd HH:mm:ss]"

    let log = String(format: "%@ %@", formatter.string(from: Date()), message)

    _ = try? stringAppendLineToURL(message: log, fileURL: file)
  }

  /// Write the message to the given file URL.
  static func stringAppendLineToURL(message: String, fileURL: URL) throws {
    let data = (message + "\n").data(using: String.Encoding.utf8)!

    if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
      defer {
        fileHandle.closeFile()
      }

      fileHandle.seekToEndOfFile()
      fileHandle.write(data)
    } else {
      try data.write(to: fileURL, options: .atomic)
    }
  }
}
