import Foundation

struct ConfigFileSystem {
  var fileExists: (String) -> Bool
  var readFile: (String) -> String?

  static let live = ConfigFileSystem(
    fileExists: { FileManager.default.fileExists(atPath: $0) },
    readFile: { try? String(contentsOfFile: $0, encoding: .utf8) }
  )
}
