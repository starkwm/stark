import Darwin
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

  @Test func returnsNotFoundWhenConfigFileDoesNotExist() {
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

  @Test func returnsReadFailedWhenConfigCannotBeRead() {
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

  @Test func successfulLoadReplacesActiveSession() throws {
    let (shortcutManager, registrar, sessionStore) = prepareRegistrar()
    defer { resetState(shortcutManager: shortcutManager, sessionStore: sessionStore) }

    let existingSession = ConfigSession()
    _ = existingSession.eventBridge.on("windowFocused", try callback())
    _ = existingSession.keymapBridge.on("return", ["cmd"], try callback())
    activate(existingSession, shortcutManager: shortcutManager, sessionStore: sessionStore)

    let manager = ConfigManager(
      shortcutManager: shortcutManager,
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: makeExecutor { session, _ in
        _ = session.eventBridge.on("windowMoved", try self.callback())
        _ = session.keymapBridge.on("escape", ["shift"], try self.callback())
      },
      path: "/tmp/stark.js",
      sessionStore: sessionStore
    )

    switch manager.load() {
    case .success:
      #expect(sessionStore.activeListenerCount(for: .windowFocused) == 0)
      #expect(sessionStore.activeListenerCount(for: .windowMoved) == 1)
      #expect(dispatchShortcut(with: registrar, keyCode: 53, flags: [.maskShift]))
      #expect(!dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
    case .failure(let error):
      Issue.record("Expected successful load, got \(error)")
    }
  }

  @Test func failedLoadPreservesPreviouslyLoadedConfiguration() throws {
    let (shortcutManager, registrar, sessionStore) = prepareRegistrar()
    defer { resetState(shortcutManager: shortcutManager, sessionStore: sessionStore) }

    let existingSession = ConfigSession()
    _ = existingSession.eventBridge.on("windowFocused", try callback())
    _ = existingSession.keymapBridge.on("return", ["cmd"], try callback())
    activate(existingSession, shortcutManager: shortcutManager, sessionStore: sessionStore)

    let manager = ConfigManager(
      shortcutManager: shortcutManager,
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: makeExecutor { session, _ in
        _ = session.eventBridge.on("windowMoved", try self.callback())
        _ = session.keymapBridge.on("escape", ["shift"], try self.callback())
        throw JSExceptionError.exception("JS exception: boom")
      },
      path: "/tmp/stark.js",
      sessionStore: sessionStore
    )

    switch manager.load() {
    case .success:
      Issue.record("Expected failed load")
    case .failure:
      #expect(sessionStore.activeListenerCount(for: .windowFocused) == 1)
      #expect(sessionStore.activeListenerCount(for: .windowMoved) == 0)
      #expect(dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
      #expect(!dispatchShortcut(with: registrar, keyCode: 53, flags: [.maskShift]))
      #expect(registrar.createCallCount == 1)
    }
  }

  @Test func startReturnsLoadFailureWithoutStartingMonitor() {
    let (shortcutManager, _, sessionStore) = prepareRegistrar()
    defer { resetState(shortcutManager: shortcutManager, sessionStore: sessionStore) }

    var monitorSetupCallCount = 0
    let manager = ConfigManager(
      shortcutManager: shortcutManager,
      fileSystem: ConfigFileSystem(
        fileExists: { _ in false },
        readFile: { _ in nil }
      ),
      path: "/tmp/stark.js",
      fileWatcher: fileWatcher {
        monitorSetupCallCount += 1
        return .success(self.makeMonitoringSource())
      },
      sessionStore: sessionStore
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
    let (shortcutManager, registrar, sessionStore) = prepareRegistrar()
    defer { resetState(shortcutManager: shortcutManager, sessionStore: sessionStore) }

    let manager = ConfigManager(
      shortcutManager: shortcutManager,
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: makeExecutor { session, _ in
        _ = session.keymapBridge.on("escape", ["shift"], try self.callback())
      },
      path: "/tmp/stark.js",
      fileWatcher: fileWatcher {
        throw FileError.monitorFailed("boom")
      },
      sessionStore: sessionStore
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

  @Test func repeatedSuccessfulLoadsReplaceStoredStateWithoutAccumulating() throws {
    let (shortcutManager, registrar, sessionStore) = prepareRegistrar()
    defer { resetState(shortcutManager: shortcutManager, sessionStore: sessionStore) }

    var loadCount = 0
    let manager = ConfigManager(
      shortcutManager: shortcutManager,
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: makeExecutor { session, _ in
        loadCount += 1

        if loadCount == 1 {
          _ = session.eventBridge.on("windowFocused", try self.callback())
          _ = session.keymapBridge.on("return", ["cmd"], try self.callback())
        } else {
          _ = session.eventBridge.on("windowMoved", try self.callback())
          _ = session.keymapBridge.on("escape", ["shift"], try self.callback())
        }
      },
      path: "/tmp/stark.js",
      sessionStore: sessionStore
    )

    switch manager.load() {
    case .success:
      #expect(sessionStore.activeListenerCount(for: .windowFocused) == 1)
      #expect(sessionStore.activeListenerCount(for: .windowMoved) == 0)
      #expect(dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
    case .failure(let error):
      Issue.record("Expected first successful load, got \(error)")
      return
    }

    switch manager.load() {
    case .success:
      #expect(sessionStore.activeListenerCount(for: .windowFocused) == 0)
      #expect(sessionStore.activeListenerCount(for: .windowMoved) == 1)
      #expect(dispatchShortcut(with: registrar, keyCode: 53, flags: [.maskShift]))
      #expect(!dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
    case .failure(let error):
      Issue.record("Expected second successful load, got \(error)")
    }
  }

  @Test func successfulStartSetsUpMonitorAndStopTearsDownShortcutHandling() throws {
    let (shortcutManager, registrar, sessionStore) = prepareRegistrar()
    defer { resetState(shortcutManager: shortcutManager, sessionStore: sessionStore) }

    var monitorSetupCallCount = 0
    let manager = ConfigManager(
      shortcutManager: shortcutManager,
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: makeExecutor { session, _ in
        _ = session.keymapBridge.on("escape", ["shift"], try self.callback())
      },
      path: "/tmp/stark.js",
      fileWatcher: fileWatcher {
        monitorSetupCallCount += 1
        return .success(self.makeMonitoringSource())
      },
      sessionStore: sessionStore
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
    let (shortcutManager, registrar, sessionStore) = prepareRegistrar()
    defer { resetState(shortcutManager: shortcutManager, sessionStore: sessionStore) }

    var loadCount = 0
    let manager = ConfigManager(
      shortcutManager: shortcutManager,
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: makeExecutor { session, _ in
        loadCount += 1

        if loadCount == 1 {
          _ = session.keymapBridge.on("return", ["lcmd"], try self.callback())
        } else {
          _ = session.keymapBridge.on("escape", ["rshift"], try self.callback())
        }
      },
      path: "/tmp/stark.js",
      sessionStore: sessionStore
    )

    switch manager.load() {
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
    case .failure(let error):
      Issue.record("Expected first load success, got \(error)")
      return
    }

    switch manager.load() {
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
    case .failure(let error):
      Issue.record("Expected second load success, got \(error)")
    }
  }

  @Test func removedModifierAliasesDoNotRegisterShortcuts() throws {
    let (shortcutManager, registrar, sessionStore) = prepareRegistrar()
    defer { resetState(shortcutManager: shortcutManager, sessionStore: sessionStore) }

    let manager = ConfigManager(
      shortcutManager: shortcutManager,
      fileSystem: ConfigFileSystem(
        fileExists: { _ in true },
        readFile: { _ in "ignored" }
      ),
      executor: makeExecutor { session, _ in
        _ = session.keymapBridge.on("return", ["option"], try self.callback())
      },
      path: "/tmp/stark.js",
      sessionStore: sessionStore
    )

    switch manager.load() {
    case .success:
      #expect(registrar.createCallCount == 0)
      #expect(!dispatchShortcut(with: registrar, keyCode: 36, flags: [.maskCommand]))
    case .failure(let error):
      Issue.record("Expected successful load with ignored invalid shortcut, got \(error)")
    }
  }

  @Test func notificationRegistrarTracksApplicationAndWindowNotificationSets() {
    var observedApplications = ApplicationNotifications(rawValue: 0)
    var observedWindows = WindowNotifications(rawValue: 0)
    var removedApplicationNotifications = [String]()
    var removedWindowNotifications = [String]()

    let applicationRegistrar = AXNotificationRegistrar<ApplicationNotifications>(
      notifications: applicationNotifications
    )
    let windowRegistrar = AXNotificationRegistrar<WindowNotifications>(
      notifications: windowNotifications
    )

    #expect(
      applicationRegistrar.observe(
        observedNotifications: &observedApplications,
        addNotification: { _ in .success },
        onFailure: { _, _ in }
      )
    )
    #expect(
      windowRegistrar.observe(
        observedNotifications: &observedWindows,
        addNotification: { _ in .success },
        onFailure: { _, _ in }
      )
    )

    applicationRegistrar.unobserve(
      observedNotifications: &observedApplications,
      removeNotification: { removedApplicationNotifications.append($0) }
    )
    windowRegistrar.unobserve(
      observedNotifications: &observedWindows,
      removeNotification: { removedWindowNotifications.append($0) }
    )

    #expect(removedApplicationNotifications.count == applicationNotifications.count)
    #expect(removedWindowNotifications.count == windowNotifications.count)
  }

  private func prepareRegistrar() -> (
    ShortcutManager, ConfigManagerShortcutTapRecorder, ConfigSessionStore
  ) {
    let registrar = ConfigManagerShortcutTapRecorder()
    let shortcutManager = ShortcutManager(
      tapFactory: registrar.makeTap(),
      handlerInvoker: { handler in handler() }
    )

    return (shortcutManager, registrar, ConfigSessionStore())
  }

  private func fileWatcher(
    startMonitoring: @escaping () throws -> Result<DispatchSourceFileSystemObject, FileError>
  ) -> ConfigFileWatcher {
    ConfigFileWatcher(
      startMonitoring: { _, _, _ in
        do {
          return try startMonitoring()
        } catch let error as FileError {
          return .failure(error)
        } catch {
          return .failure(.monitorFailed("\(error)"))
        }
      }
    )
  }

  private func makeMonitoringSource() -> DispatchSourceFileSystemObject {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: url.path, contents: Data())

    let fileDescriptor = open(url.path, O_EVTONLY)
    precondition(fileDescriptor >= 0, "Failed to open temp file for config monitor stub")

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileDescriptor,
      eventMask: [.write],
      queue: DispatchQueue(label: "dev.tombell.stark.config.tests")
    )
    source.setEventHandler {}
    source.setCancelHandler {
      close(fileDescriptor)
      try? FileManager.default.removeItem(at: url)
    }
    source.resume()

    return source
  }

  private func resetState(shortcutManager: ShortcutManager, sessionStore: ConfigSessionStore) {
    shortcutManager.stop()
    shortcutManager.reset()
    sessionStore.replace(with: nil)?.deactivate()
  }

  private func activate(
    _ session: ConfigSession,
    shortcutManager: ShortcutManager,
    sessionStore: ConfigSessionStore
  ) {
    shortcutManager.stop()
    shortcutManager.reset()
    sessionStore.replace(with: session)?.deactivate()
    session.activate(with: shortcutManager)
    shortcutManager.start()
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

  private func makeExecutor(
    execute: @escaping (ConfigSession, JSContext) throws -> Void
  ) -> ConfigExecutor {
    ConfigExecutor(
      createContext: { session in
        guard let context = JSContext() else {
          throw JSExceptionError.exception("Could not create javascript context")
        }

        session.attach(context: context)
        return context
      },
      executeScript: { session, context, _ in
        try execute(session, context)
      }
    )
  }
}

private enum CallbackError: Error {
  case contextCreationFailed
  case callbackCreationFailed
}
