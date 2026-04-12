import AppKit
import JavaScriptCore

private let primaryPaths: [String] = [
  "~/.stark.js",
  "~/.config/stark/stark.js",
  "~/Library/Application Support/Stark/stark.js",
]

final class ConfigManager {
  private let fileSystem: ConfigFileSystem
  private let executor: ConfigExecutor
  private let fileWatcher: ConfigFileWatcher
  private let fileMonitorSetup: (ConfigManager) -> Result<Void, FileError>
  private let shortcutManager: ShortcutManager
  private var path: String
  private var fileSystemSource: DispatchSourceFileSystemObject?
  private let fileMonitorQueue = DispatchQueue(label: "dev.tombell.stark.config")

  private var context: JSContext?

  init(
    shortcutManager: ShortcutManager = ShortcutManager(),
    fileSystem: ConfigFileSystem = .live,
    executor: ConfigExecutor? = nil,
    path: String? = nil,
    pathResolver: ConfigPathResolver = .live,
    fileWatcher: ConfigFileWatcher = .live,
    fileMonitorSetup: ((ConfigManager) -> Result<Void, FileError>)? = nil
  ) {
    let runtimeFactory = ScriptRuntimeFactory.live()
    let scriptExecutor = ConfigScriptExecutor.live

    self.shortcutManager = shortcutManager
    self.fileSystem = fileSystem
    self.executor =
      executor
      ?? ConfigExecutor(
        createContext: runtimeFactory.createContext,
        executeScript: scriptExecutor.executeScript
      )
    self.fileWatcher = fileWatcher
    self.path = path ?? pathResolver.resolvePrimaryPath(primaryPaths, fileSystem)
    self.fileMonitorSetup = fileMonitorSetup ?? { manager in manager.setupFileMonitor() }
  }

  static func resolvePrimaryPath(
    paths: [String] = primaryPaths,
    fileSystem: ConfigFileSystem = .live
  ) -> String {
    ConfigPathResolver.live.resolvePrimaryPath(paths, fileSystem)
  }

  func start() -> Result<Void, Error> {
    switch load() {
    case .success:
      break
    case .failure(let error):
      return .failure(error)
    }

    switch fileMonitorSetup(self) {
    case .success:
      return .success(())
    case .failure(let error):
      return .failure(error)
    }
  }

  func stop() {
    fileSystemSource?.cancel()
    fileSystemSource = nil

    shortcutManager.stop()
  }

  func load() -> Result<Void, Error> {
    let nextContext: JSContext

    switch executor.createContext() {
    case .success(let context):
      nextContext = context
    case .failure(let error):
      return .failure(error)
    }

    Keymap.configureShortcutManager(shortcutManager)
    Keymap.beginRecording()
    Event.beginRecording()

    switch executeConfig(in: nextContext) {
    case .success:
      shortcutManager.stop()
      shortcutManager.reset()

      context = nextContext

      Event.commitRecording()
      Keymap.commitRecording()
      shortcutManager.start()

      return .success(())
    case .failure(let error):
      Keymap.discardRecording()
      Event.discardRecording()
      return .failure(error)
    }
  }

  private func executeConfig(in context: JSContext) -> Result<Void, Error> {
    let scriptContents: String

    switch readConfigScript() {
    case .success(let contents):
      scriptContents = contents
    case .failure(let error):
      return .failure(error)
    }

    return executor.executeScript(context, scriptContents)
  }

  func readConfigScript() -> Result<String, Error> {
    if !fileSystem.fileExists(path) {
      return .failure(FileError.notFound(path))
    }

    guard let scriptContents = fileSystem.readFile(path) else {
      return .failure(FileError.readFailed("could not read file \(path)"))
    }

    return .success(scriptContents)
  }

  private func setupFileMonitor() -> Result<Void, FileError> {
    switch fileWatcher.startMonitoring(path, fileMonitorQueue, handleFileWatchReload) {
    case .success(let source):
      fileSystemSource = source
      return .success(())
    case .failure(let error):
      return .failure(error)
    }
  }

  private func reloadConfig() {
    let reload = {
      log("config file changed, reloading...", level: .info)

      switch self.load() {
      case .success: break
      case .failure(let error):
        log("could not reload config file: \(error)", level: .error)
      }
    }

    if Thread.isMainThread {
      reload()
    } else {
      DispatchQueue.main.async(execute: reload)
    }
  }

  private func restartFileMonitor() {
    fileSystemSource?.cancel()
    fileSystemSource = nil

    switch fileMonitorSetup(self) {
    case .success: break
    case .failure(let error):
      log("could not restart config monitor: \(error)", level: .error)
    }
  }

  private func handleFileWatchReload(needsMonitorRestart: Bool) {
    if needsMonitorRestart {
      restartFileMonitor()
    }

    reloadConfig()
  }

}
