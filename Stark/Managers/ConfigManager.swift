import AppKit
import JavaScriptCore

private let primaryPaths: [String] = [
  "~/.stark.js",
  "~/.config/stark/stark.js",
  "~/Library/Application Support/Stark/stark.js",
]

struct ConfigFileSystem {
  var fileExists: (String) -> Bool
  var readFile: (String) -> String?

  static let live = ConfigFileSystem(
    fileExists: { FileManager.default.fileExists(atPath: $0) },
    readFile: { try? String(contentsOfFile: $0, encoding: .utf8) }
  )
}

struct ConfigExecutor {
  var createContext: () -> Result<JSContext, JSExceptionError>
  var executeScript: (JSContext, String) -> Result<Void, Error>
}

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

  func loadForTesting() -> Result<Void, Error> {
    load()
  }
}
