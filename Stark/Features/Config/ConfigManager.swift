import AppKit
import JavaScriptCore

private let primaryPaths: [String] = [
  "~/.stark.js",
  "~/.config/stark/stark.js",
  "~/Library/Application Support/Stark/stark.js",
]

/// Manages JavaScript configuration loading and monitoring.
/// Loads user configuration from ~/.stark.js and watches for changes.
final class ConfigManager {
  static var shared = ConfigManager()

  private let fileSystem: ConfigFileSystem
  private let executor: ConfigExecutor
  private let fileWatcher: ConfigFileWatcher
  private let fileMonitorSetup: (ConfigManager) -> Result<Void, FileError>
  private var path: String
  private var fileSystemSource: DispatchSourceFileSystemObject?
  private let fileMonitorQueue = DispatchQueue(label: "dev.tombell.stark.config")

  private var context: JSContext?

  init(
    fileSystem: ConfigFileSystem = .live,
    executor: ConfigExecutor? = nil,
    path: String? = nil,
    pathResolver: ConfigPathResolver = .live,
    fileWatcher: ConfigFileWatcher = .live,
    fileMonitorSetup: ((ConfigManager) -> Result<Void, FileError>)? = nil
  ) {
    let runtimeFactory = ScriptRuntimeFactory.live()
    let scriptExecutor = ConfigScriptExecutor.live

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

  /// Resolves the highest-priority config path, even if the file does not yet exist.
  static func resolvePrimaryPath(
    paths: [String] = primaryPaths,
    fileSystem: ConfigFileSystem = .live
  ) -> String {
    ConfigPathResolver.live.resolvePrimaryPath(paths, fileSystem)
  }

  /// Starts the configuration manager, loading the config file and setting up file monitoring.
  /// - Returns: Success or failure with error details
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

  /// Stops the configuration manager and cleans up resources.
  func stop() {
    fileSystemSource?.cancel()
    fileSystemSource = nil

    ShortcutManager.stop()
  }

  /// Builds a fresh JS context and atomically swaps newly declared bindings into the live runtime.
  private func load() -> Result<Void, Error> {
    let nextContext: JSContext

    switch executor.createContext() {
    case .success(let context):
      nextContext = context
    case .failure(let error):
      return .failure(error)
    }

    Keymap.beginRecording()
    Event.beginRecording()

    switch executeConfig(in: nextContext) {
    case .success:
      ShortcutManager.stop()
      ShortcutManager.reset()

      context = nextContext

      Event.commitRecording()
      Keymap.commitRecording()
      ShortcutManager.start()

      return .success(())
    case .failure(let error):
      Keymap.discardRecording()
      Event.discardRecording()
      return .failure(error)
    }
  }

  /// Reads the current config file and evaluates it inside the provided JS context.
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

  /// Reads the selected configuration script from disk.
  func readConfigScript() -> Result<String, Error> {
    if !fileSystem.fileExists(path) {
      return .failure(FileError.notFound(path))
    }

    guard let scriptContents = fileSystem.readFile(path) else {
      return .failure(FileError.readFailed("could not read file \(path)"))
    }

    return .success(scriptContents)
  }

  /// Starts watching the active config file for writes, renames, and deletes.
  private func setupFileMonitor() -> Result<Void, FileError> {
    switch fileWatcher.startMonitoring(path, fileMonitorQueue, handleFileWatchReload) {
    case .success(let source):
      fileSystemSource = source
      return .success(())
    case .failure(let error):
      return .failure(error)
    }
  }

  /// Reloads the configuration on the main thread so AppKit and JS state stay serialized.
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

  /// Recreates the file watcher after the underlying file descriptor becomes invalid.
  private func restartFileMonitor() {
    fileSystemSource?.cancel()
    fileSystemSource = nil

    switch fileMonitorSetup(self) {
    case .success: break
    case .failure(let error):
      log("could not restart config monitor: \(error)", level: .error)
    }
  }

  /// Handles file watcher events that may require both a reload and watcher restart.
  private func handleFileWatchReload(needsMonitorRestart: Bool) {
    if needsMonitorRestart {
      restartFileMonitor()
    }

    reloadConfig()
  }

  /// Exposes the core load path without installing file monitoring.
  func loadForTesting() -> Result<Void, Error> {
    load()
  }
}
