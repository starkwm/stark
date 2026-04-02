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
  private let fileMonitorSetup: (ConfigManager) -> Result<Void, FileError>
  private var path: String
  private var fileSystemSource: DispatchSourceFileSystemObject?
  private let fileMonitorQueue = DispatchQueue(label: "dev.tombell.stark.config")

  private var context: JSContext?

  init(
    fileSystem: ConfigFileSystem = .live,
    executor: ConfigExecutor? = nil,
    path: String? = nil,
    fileMonitorSetup: ((ConfigManager) -> Result<Void, FileError>)? = nil
  ) {
    self.fileSystem = fileSystem
    self.executor =
      executor
      ?? ConfigExecutor(
        createContext: { Self.liveCreateContext() },
        executeScript: { context, script in Self.liveExecuteScript(in: context, script: script) }
      )
    self.path = path ?? Self.resolvePrimaryPath(fileSystem: fileSystem)
    self.fileMonitorSetup = fileMonitorSetup ?? { manager in manager.liveSetupFileMonitor() }
  }

  static func resolvePrimaryPath(
    paths: [String] = primaryPaths,
    fileSystem: ConfigFileSystem = .live
  ) -> String {
    return paths
      .lazy
      .map { ($0 as NSString).resolvingSymlinksInPath }
      .first { fileSystem.fileExists($0) }
      ?? (paths[0] as NSString).resolvingSymlinksInPath
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

  private static func liveCreateContext() -> Result<JSContext, JSExceptionError> {
    let context = JSContext(virtualMachine: JSVirtualMachine())

    guard let context else {
      return .failure(.exception("Could not create javascript context"))
    }

    context.exceptionHandler = { _, err in
      log("javascript exception - \(String(describing: err))", level: .error)
    }

    let print: @convention(block) (String) -> Void = { message in
      log(message, level: .info)
    }
    context.setObject(print, forKeyedSubscript: "print" as NSString)
    context.setObject(Keymap.self, forKeyedSubscript: "Keymap" as NSString)
    context.setObject(Event.self, forKeyedSubscript: "Event" as NSString)
    context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as NSString)
    context.setObject(Space.self, forKeyedSubscript: "Space" as NSString)
    context.setObject(Application.self, forKeyedSubscript: "Application" as NSString)
    context.setObject(Window.self, forKeyedSubscript: "Window" as NSString)

    return .success(context)
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

  private static func liveExecuteScript(in context: JSContext, script: String) -> Result<
    Void, Error
  > {
    context.evaluateScript(script)

    if let exception = context.exception {
      return .failure(JSExceptionError.exception("JS exception: \(exception)"))
    }

    return .success(())
  }

  private func liveSetupFileMonitor() -> Result<Void, FileError> {
    let file = NSURL.fileURL(withPath: path)
    let fd = open(file.path, O_EVTONLY)

    guard fd >= 0 else {
      return .failure(.monitorFailed("could not open config file for monitoring"))
    }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd,
      eventMask: [.write, .delete, .rename],
      queue: fileMonitorQueue
    )

    fileSystemSource = source

    source.setEventHandler { [weak self, weak source] in
      guard let self, let source else { return }

      let events = source.data
      let needsMonitorRestart = events.contains(.delete) || events.contains(.rename)
      let needsReload = needsMonitorRestart || events.contains(.write)

      if needsMonitorRestart {
        self.restartFileMonitor()
      }

      if needsReload {
        self.reloadConfig()
      }
    }

    source.setCancelHandler {
      close(fd)
    }

    source.resume()

    return .success(())
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

  func loadForTesting() -> Result<Void, Error> {
    load()
  }
}
