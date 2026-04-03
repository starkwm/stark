import Foundation
import IOKit.hidsystem
import JavaScriptCore
import Testing

@testable import Stark

private final class ConfigManagerShortcutTapRecorder {
  final class SpyShortcutTap: ShortcutTapType {
    let enableHandler: (Bool) -> Void
    let invalidateHandler: () -> Void

    init(enableHandler: @escaping (Bool) -> Void, invalidateHandler: @escaping () -> Void) {
      self.enableHandler = enableHandler
      self.invalidateHandler = invalidateHandler
    }

    func enable(_ enabled: Bool) {
      enableHandler(enabled)
    }

    func invalidate() {
      invalidateHandler()
    }
  }

  var createCallCount = 0
  var invalidateCallCount = 0
  var eventHandler: ShortcutManager.EventHandler?

  func makeTap() -> ShortcutManager.TapFactory {
    { eventHandler in
      self.createCallCount += 1
      self.eventHandler = eventHandler
      return SpyShortcutTap(
        enableHandler: { _ in },
        invalidateHandler: {
          self.invalidateCallCount += 1
        }
      )
    }
  }
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

  @Test func returnsReadFailedWhenConfigCannotBeRead() throws {
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

  @Test func successfulLoadCommitsRecordedState() throws {
    let (shortcutManager, registrar) = prepareRegistrar()
    defer { resetState() }

    _ = Event.on("windowFocused", try callback())
    _ = Keymap.on("return", ["cmd"], try callback())

    let manager = ConfigManager(
      shortcutManager: shortcutManager,
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
      #expect(dispatchShortcut(with: registrar, keyCode: 53, flags: [.maskShift]))
      #expect(!dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
    case .failure(let error):
      Issue.record("Expected successful load, got \(error)")
    }
  }

  @Test func failedLoadDiscardsRecordedStateAndPreservesActiveState() throws {
    let (shortcutManager, registrar) = prepareRegistrar()
    defer { resetState() }

    _ = Event.on("windowFocused", try callback())
    _ = Keymap.on("return", ["cmd"], try callback())

    let manager = ConfigManager(
      shortcutManager: shortcutManager,
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
      shortcutManager.start()
      #expect(Event.activeListenerCount(for: .windowFocused) == 1)
      #expect(Event.activeListenerCount(for: .windowMoved) == 0)
      #expect(Event.recordingListenerCount(for: .windowMoved) == 0)
      #expect(dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
      #expect(!dispatchShortcut(with: registrar, keyCode: 53, flags: [.maskShift]))
    }
  }

  @Test func startReturnsLoadFailureWithoutStartingMonitor() {
    let shortcutManager = prepareState()
    defer { resetState() }

    var monitorSetupCallCount = 0
    let manager = ConfigManager(
      shortcutManager: shortcutManager,
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
    let (shortcutManager, registrar) = prepareRegistrar()
    defer { resetState() }

    let manager = ConfigManager(
      shortcutManager: shortcutManager,
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
        #expect(registrar.createCallCount == 1)
        #expect(dispatchShortcut(with: registrar, keyCode: 53, flags: [.maskShift]))
      default:
        Issue.record("Expected FileError.monitorFailed, got \(error)")
      }
    case .failure(let error):
      Issue.record("Expected FileError.monitorFailed, got \(error)")
    }
  }

  @Test func executorJavascriptExceptionsArePropagated() {
    let shortcutManager = prepareState()
    defer { resetState() }

    let manager = ConfigManager(
      shortcutManager: shortcutManager,
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
    let (shortcutManager, registrar) = prepareRegistrar()
    defer { resetState() }

    var loadCount = 0
    let manager = ConfigManager(
      shortcutManager: shortcutManager,
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
      #expect(dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
      #expect(!dispatchShortcut(with: registrar, keyCode: 53, flags: [.maskShift]))
    case .failure(let error):
      Issue.record("Expected first successful load, got \(error)")
      return
    }

    switch manager.loadForTesting() {
    case .success:
      #expect(Event.activeListenerCount(for: .windowFocused) == 0)
      #expect(Event.activeListenerCount(for: .windowMoved) == 1)
      #expect(Event.recordingListenerCount(for: .windowFocused) == 0)
      #expect(Event.recordingListenerCount(for: .windowMoved) == 0)
      #expect(dispatchShortcut(with: registrar, keyCode: 53, flags: [.maskShift]))
      #expect(!dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
    case .failure(let error):
      Issue.record("Expected second successful load, got \(error)")
    }
  }

  @Test func failedReloadPreservesPreviouslyLoadedConfiguration() throws {
    let (shortcutManager, registrar) = prepareRegistrar()
    defer { resetState() }

    var loadCount = 0
    let manager = ConfigManager(
      shortcutManager: shortcutManager,
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
              return .success(())
            }

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

    switch manager.loadForTesting() {
    case .success:
      #expect(Event.activeListenerCount(for: .windowFocused) == 1)
      #expect(Event.activeListenerCount(for: .windowMoved) == 0)
      #expect(dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
      #expect(registrar.createCallCount == 1)
    case .failure(let error):
      Issue.record("Expected first successful load, got \(error)")
      return
    }

    switch manager.loadForTesting() {
    case .success:
      Issue.record("Expected second load to fail")
    case .failure:
      #expect(Event.activeListenerCount(for: .windowFocused) == 1)
      #expect(Event.activeListenerCount(for: .windowMoved) == 0)
      #expect(dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
      #expect(!dispatchShortcut(with: registrar, keyCode: 53, flags: [.maskShift]))
      #expect(registrar.createCallCount == 1)
    }
  }

  @Test func successfulStartSetsUpMonitorAndStopTearsDownShortcutHandling() throws {
    let (shortcutManager, registrar) = prepareRegistrar()
    defer { resetState() }

    var monitorSetupCallCount = 0
    let manager = ConfigManager(
      shortcutManager: shortcutManager,
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
      fileMonitorSetup: { _ in
        monitorSetupCallCount += 1
        return .success(())
      }
    )

    switch manager.start() {
    case .success:
      #expect(monitorSetupCallCount == 1)
      #expect(registrar.createCallCount == 1)
      #expect(dispatchShortcut(with: registrar, keyCode: 53, flags: [.maskShift]))
    case .failure(let error):
      Issue.record("Expected start success, got \(error)")
      return
    }

    manager.stop()

    #expect(registrar.invalidateCallCount == 1)
  }

  @Test func sidedModifierBindingsSurviveReload() throws {
    let (shortcutManager, registrar) = prepareRegistrar()
    defer { resetState() }

    var loadCount = 0
    let manager = ConfigManager(
      shortcutManager: shortcutManager,
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
              _ = Keymap.on("return", ["lcmd"], try self.callback())
            } else {
              _ = Keymap.on("escape", ["rshift"], try self.callback())
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
      #expect(
        dispatchShortcut(
          with: registrar,
          keyCode: 36,
          flags: [.maskCommand],
          deviceMasks: [NX_DEVICELCMDKEYMASK]
        )
      )
      #expect(
        !dispatchShortcut(
          with: registrar,
          keyCode: 36,
          flags: [.maskCommand],
          deviceMasks: [NX_DEVICERCMDKEYMASK]
        )
      )
      #expect(registrar.createCallCount == 1)
    case .failure(let error):
      Issue.record("Expected first load success, got \(error)")
      return
    }

    switch manager.loadForTesting() {
    case .success:
      #expect(
        dispatchShortcut(
          with: registrar,
          keyCode: 53,
          flags: [.maskShift],
          deviceMasks: [NX_DEVICERSHIFTKEYMASK]
        )
      )
      #expect(
        !dispatchShortcut(
          with: registrar,
          keyCode: 53,
          flags: [.maskShift],
          deviceMasks: [NX_DEVICELSHIFTKEYMASK]
        )
      )
      #expect(registrar.createCallCount == 2)
    case .failure(let error):
      Issue.record("Expected second load success, got \(error)")
    }
  }

  @Test func removedModifierAliasesDoNotRegisterShortcuts() throws {
    let (shortcutManager, registrar) = prepareRegistrar()
    defer { resetState() }

    let manager = ConfigManager(
      shortcutManager: shortcutManager,
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
            _ = Keymap.on("return", ["option"], try self.callback())
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
      #expect(registrar.createCallCount == 0)
      #expect(!dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
    case .failure(let error):
      Issue.record("Expected successful load with ignored invalid shortcut, got \(error)")
    }
  }

  private func prepareState() -> ShortcutManager {
    let (shortcutManager, _) = prepareRegistrar()
    return shortcutManager
  }

  private func prepareRegistrar() -> (ShortcutManager, ConfigManagerShortcutTapRecorder) {
    resetState()

    let registrar = ConfigManagerShortcutTapRecorder()
    let shortcutManager = ShortcutManager(
      tapFactory: registrar.makeTap(),
      handlerInvoker: { handler in handler() }
    )
    Keymap.configureShortcutManager(shortcutManager)

    return (shortcutManager, registrar)
  }

  private func resetState() {
    Event.resetForTesting()
    Keymap.discardRecording()
    Keymap.reset()
    Keymap.configureShortcutManager(ShortcutManager())
  }

  private func dispatchShortcut(
    with registrar: ConfigManagerShortcutTapRecorder,
    keyCode: UInt32,
    flags: [CGEventFlags],
    deviceMasks: [Int32] = []
  ) -> Bool {
    let event = CGEvent(
      keyboardEventSource: nil,
      virtualKey: CGKeyCode(keyCode),
      keyDown: true
    )!
    let rawValue =
      flags.reduce(CGEventFlags()) { $0.union($1) }.rawValue
      | UInt64(UInt32(bitPattern: deviceMasks.reduce(0, |)))
    event.flags = CGEventFlags(rawValue: rawValue)

    guard let eventHandler = registrar.eventHandler else {
      return false
    }

    return eventHandler(.keyDown, event) == nil
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

extension ConfigManager {
  fileprivate func loadForTesting() -> Result<Void, Error> {
    load()
  }
}
