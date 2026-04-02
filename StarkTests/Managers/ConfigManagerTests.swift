import Foundation
import JavaScriptCore
import Testing

@testable import Stark

private final class ConfigManagerShortcutRegistrar: ShortcutRegistrar {
  func register(keyCode _: UInt32, modifiers _: UInt32, hotKeyID _: UInt32, signature _: OSType)
    -> Bool
  {
    true
  }

  func unregister(hotKeyID _: UInt32) {}
  func installEventHandler() -> Bool { true }
  func removeEventHandler() {}
}

@Suite(.serialized) struct ConfigManagerTests {
  @Test func resolvesPrimaryPathUsingPriorityOrder() {
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

  @Test func fallsBackToFirstPrimaryPathWhenNoFileExists() {
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

  @Test func returnsNotFoundWhenConfigFileDoesNotExist() throws {
    let path = "/tmp/stark.js"
    let manager = ConfigManager(
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

  @Test func returnsReadFailedWhenConfigCannotBeRead() throws {
    let path = "/tmp/stark.js"
    let manager = ConfigManager(
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

  @Test func successfulLoadCommitsRecordedState() throws {
    prepareState()
    defer { resetState() }

    _ = Event.on("windowFocused", try callback())
    _ = Keymap.on("return", ["cmd"], try callback())

    let manager = ConfigManager(
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: ConfigExecutor(
        createContext: {
          guard let context = JSContext() else {
            return .failure(.exception("Could not create javascript context"))
          }

          return .success(context)
        },
        executeScript: { _, _ in
          do {
            _ = Event.on("windowMoved", try self.callback())
            _ = Keymap.on("escape", ["shift"], try self.callback())
            return .success(())
          } catch {
            return .failure(error)
          }
        }
      ),
      path: "/tmp/stark.js",
      fileMonitorSetup: { _ in .success(()) }
    )

    let result = manager.loadForTesting()

    switch result {
    case .success:
      #expect(Event.activeListenerCount(for: .windowFocused) == 0)
      #expect(Event.activeListenerCount(for: .windowMoved) == 1)
      #expect(Keymap.activeIDsForTesting == ["escape[shift]"])
      #expect(Keymap.recordingIDsForTesting.isEmpty)
    case .failure(let error):
      Issue.record("Expected successful load, got \(error)")
    }
  }

  @Test func failedLoadDiscardsRecordedStateAndPreservesActiveState() throws {
    prepareState()
    defer { resetState() }

    _ = Event.on("windowFocused", try callback())
    _ = Keymap.on("return", ["cmd"], try callback())

    let manager = ConfigManager(
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: ConfigExecutor(
        createContext: {
          guard let context = JSContext() else {
            return .failure(.exception("Could not create javascript context"))
          }

          return .success(context)
        },
        executeScript: { _, _ in
          do {
            _ = Event.on("windowMoved", try self.callback())
            _ = Keymap.on("escape", ["shift"], try self.callback())
            return .failure(JSExceptionError.exception("JS exception: boom"))
          } catch {
            return .failure(error)
          }
        }
      ),
      path: "/tmp/stark.js",
      fileMonitorSetup: { _ in .success(()) }
    )

    let result = manager.loadForTesting()

    switch result {
    case .success:
      Issue.record("Expected failed load")
    case .failure:
      #expect(Event.activeListenerCount(for: .windowFocused) == 1)
      #expect(Event.activeListenerCount(for: .windowMoved) == 0)
      #expect(Event.recordingListenerCount(for: .windowMoved) == 0)
      #expect(Keymap.activeIDsForTesting == ["return[cmd]"])
      #expect(Keymap.recordingIDsForTesting.isEmpty)
    }
  }

  @Test func startReturnsLoadFailureWithoutStartingMonitor() {
    prepareState()
    defer { resetState() }

    var monitorSetupCallCount = 0
    let manager = ConfigManager(
      fileSystem: ConfigFileSystem(
        fileExists: { _ in false },
        readFile: { _ in nil }
      ),
      path: "/tmp/stark.js",
      fileMonitorSetup: { _ in
        monitorSetupCallCount += 1
        return .success(())
      }
    )

    let result = manager.start()

    switch result {
    case .success:
      Issue.record("Expected load failure")
    case .failure:
      #expect(monitorSetupCallCount == 0)
    }
  }

  @Test func startReturnsMonitorFailureAfterSuccessfulLoad() throws {
    prepareState()
    defer { resetState() }

    let manager = ConfigManager(
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: ConfigExecutor(
        createContext: {
          guard let context = JSContext() else {
            return .failure(.exception("Could not create javascript context"))
          }

          return .success(context)
        },
        executeScript: { _, _ in
          do {
            _ = Keymap.on("escape", ["shift"], try self.callback())
            return .success(())
          } catch {
            return .failure(error)
          }
        }
      ),
      path: "/tmp/stark.js",
      fileMonitorSetup: { _ in .failure(.monitorFailed("boom")) }
    )

    let result = manager.start()

    switch result {
    case .success:
      Issue.record("Expected monitor setup failure")
    case .failure(let error as FileError):
      switch error {
      case .monitorFailed(let message):
        #expect(message == "boom")
        #expect(Keymap.activeIDsForTesting == ["escape[shift]"])
      default:
        Issue.record("Expected FileError.monitorFailed, got \(error)")
      }
    case .failure(let error):
      Issue.record("Expected FileError.monitorFailed, got \(error)")
    }
  }

  @Test func executorJavascriptExceptionsArePropagated() {
    prepareState()
    defer { resetState() }

    let manager = ConfigManager(
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: ConfigExecutor(
        createContext: {
          guard let context = JSContext() else {
            return .failure(.exception("Could not create javascript context"))
          }

          return .success(context)
        },
        executeScript: { _, _ in
          .failure(JSExceptionError.exception("JS exception: boom"))
        }
      ),
      path: "/tmp/stark.js",
      fileMonitorSetup: { _ in .success(()) }
    )

    let result = manager.loadForTesting()

    switch result {
    case .success:
      Issue.record("Expected javascript exception")
    case .failure(let error as JSExceptionError):
      switch error {
      case .exception(let message):
        #expect(message.contains("boom"))
      }
    case .failure(let error):
      Issue.record("Expected JSExceptionError, got \(error)")
    }
  }

  @Test func repeatedSuccessfulLoadsReplaceRecordedStateWithoutAccumulating() throws {
    prepareState()
    defer { resetState() }

    var loadCount = 0
    let manager = ConfigManager(
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: ConfigExecutor(
        createContext: {
          guard let context = JSContext() else {
            return .failure(.exception("Could not create javascript context"))
          }

          return .success(context)
        },
        executeScript: { _, _ in
          do {
            loadCount += 1

            if loadCount == 1 {
              _ = Event.on("windowFocused", try self.callback())
              _ = Keymap.on("return", ["cmd"], try self.callback())
            } else {
              _ = Event.on("windowMoved", try self.callback())
              _ = Keymap.on("escape", ["shift"], try self.callback())
            }

            return .success(())
          } catch {
            return .failure(error)
          }
        }
      ),
      path: "/tmp/stark.js",
      fileMonitorSetup: { _ in .success(()) }
    )

    switch manager.loadForTesting() {
    case .success:
      #expect(Event.activeListenerCount(for: .windowFocused) == 1)
      #expect(Event.activeListenerCount(for: .windowMoved) == 0)
      #expect(Keymap.activeIDsForTesting == ["return[cmd]"])
    case .failure(let error):
      Issue.record("Expected first successful load, got \(error)")
      return
    }

    switch manager.loadForTesting() {
    case .success:
      #expect(Event.activeListenerCount(for: .windowFocused) == 0)
      #expect(Event.activeListenerCount(for: .windowMoved) == 1)
      #expect(Keymap.activeIDsForTesting == ["escape[shift]"])
      #expect(Event.recordingListenerCount(for: .windowFocused) == 0)
      #expect(Event.recordingListenerCount(for: .windowMoved) == 0)
      #expect(Keymap.recordingIDsForTesting.isEmpty)
    case .failure(let error):
      Issue.record("Expected second successful load, got \(error)")
    }
  }

  private func prepareState() {
    resetState()
    ShortcutManager.useRegistrar(ConfigManagerShortcutRegistrar())
  }

  private func resetState() {
    Event.resetForTesting()
    Keymap.resetForTesting()
    ShortcutManager.resetForTesting()
  }

  private func callback() throws -> JSValue {
    guard let context = JSContext() else {
      throw CallbackError.contextCreationFailed
    }

    guard let callback = context.evaluateScript("(() => {})") else {
      throw CallbackError.callbackCreationFailed
    }

    return callback
  }
}

private enum CallbackError: Error {
  case contextCreationFailed
  case callbackCreationFailed
}
