import Testing

@testable import Stark

@Suite
struct ConfigManagerTests {
  @Test
  func resolvesPrimaryPathUsingPriorityOrder() {
    let paths = [
      "/tmp/first.js",
      "/tmp/second.js",
      "/tmp/third.js",
    ]
    let existingPaths = Set([paths[1], paths[2]])
    let fileSystem = ConfigFileSystem(
      fileExists: { existingPaths.contains($0) },
      readFile: { _ in nil }
    )

    let resolved = ConfigManager.resolvePrimaryPath(paths: paths, fileSystem: fileSystem)

    #expect(resolved == paths[1])
  }

  @Test
  func fallsBackToFirstPrimaryPathWhenNoFileExists() {
    let paths = [
      "/tmp/first.js",
      "/tmp/second.js",
    ]
    let fileSystem = ConfigFileSystem(
      fileExists: { _ in false },
      readFile: { _ in nil }
    )

    let resolved = ConfigManager.resolvePrimaryPath(paths: paths, fileSystem: fileSystem)

    #expect(resolved == paths[0])
  }

  @Test
  func returnsNotFoundWhenConfigFileDoesNotExist() {
    let path = "/tmp/stark.js"
    let manager = ConfigManager(
      shortcutManager: ShortcutManager(),
      fileSystem: ConfigFileSystem(
        fileExists: { _ in false },
        readFile: { _ in nil }
      ),
      path: path
    )

    let result = manager.readConfigScript()

    switch result {
    case .success:
      Issue.record("Expected missing file failure")
    case .failure(let error as FileError):
      switch error {
      case .notFound(let missingPath):
        #expect(missingPath == path)
      default:
        Issue.record("Expected FileError.notFound, got \(error)")
      }
    case .failure(let error):
      Issue.record("Expected FileError.notFound, got \(error)")
    }
  }

  @Test
  func returnsReadFailedWhenConfigCannotBeRead() {
    let path = "/tmp/stark.js"
    let manager = ConfigManager(
      shortcutManager: ShortcutManager(),
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in nil }
      ),
      path: path
    )

    let result = manager.readConfigScript()

    switch result {
    case .success:
      Issue.record("Expected read failure")
    case .failure(let error as FileError):
      switch error {
      case .readFailed(let message):
        #expect(message.contains(path))
      default:
        Issue.record("Expected FileError.readFailed, got \(error)")
      }
    case .failure(let error):
      Issue.record("Expected FileError.readFailed, got \(error)")
    }
  }
}
