import Foundation

struct LogHelper: TextOutputStream {
  func write(_ string: String) {
    let fm = FileManager.default
    let log = fm.urls(for: .userDirectory, in: .userDomainMask)[0].appendingPathComponent(".stark.log")

    if let handle = try? FileHandle(forWritingTo: log) {
      handle.seekToEndOfFile()
      handle.write(string.data(using: .utf8)!)
      handle.closeFile()
    } else {
      try? string.data(using: .utf8)?.write(to: log)
    }
  }
}

let logger = LogHelper()
