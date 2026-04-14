import Foundation

struct ConfigFileSystem {
  static let live = ConfigFileSystem(
    fileExists: { FileManager.default.fileExists(atPath: $0) },
    readFile: { try? String(contentsOfFile: $0, encoding: .utf8) }
  )

  var fileExists: (String) -> Bool
  var readFile: (String) -> String?
}
