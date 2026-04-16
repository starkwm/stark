import JavaScriptCore

private let primaryPaths: [String] = [
  "~/.stark.js",
  "~/.config/stark/stark.js",
  "~/Library/Application Support/Stark/stark.js",
]

protocol EventListenerProviding: AnyObject {
  func callbacks(for event: EventType) -> [Event]
}

final class ConfigSessionStore: EventListenerProviding {
  static let shared = ConfigSessionStore()

  private let queue = DispatchQueue(label: "dev.tombell.stark.config.session-store")
  private var session: ConfigSession?

  @discardableResult
  func replace(with session: ConfigSession?) -> ConfigSession? {
    queue.sync {
      let previous = self.session
      self.session = session
      return previous
    }
  }

  func activeSession() -> ConfigSession? {
    queue.sync { session }
  }

  func callbacks(for event: EventType) -> [Event] {
    queue.sync { session?.callbacks(for: event) ?? [] }
  }

  func activeListenerCount(for event: EventType) -> Int {
    queue.sync { session?.activeListenerCount(for: event) ?? 0 }
  }
}

final class ConfigSession {
  lazy var keymapBridge = KeymapBridge(session: self)
  lazy var eventBridge = EventBridge(session: self)

  private(set) var context: JSContext?
  private var keymapsByID = [String: Keymap]()
  private var listenersByEvent = [EventType: [Event]]()
  private weak var shortcutManager: ShortcutManager?

  func attach(context: JSContext) {
    self.context = context
  }

  func activate(with shortcutManager: ShortcutManager) {
    self.shortcutManager = shortcutManager

    for keymap in keymapsByID.values {
      keymap.activate(with: shortcutManager)
    }
  }

  func deactivate() {
    if let shortcutManager {
      for keymap in keymapsByID.values {
        keymap.deactivate(with: shortcutManager)
      }
    }

    shortcutManager = nil
  }

  @discardableResult
  func registerKeymap(_ key: String, modifiers: [String], callback: JSValue) -> Keymap {
    let keymap = Keymap(
      key: key,
      modifiers: modifiers,
      callback: callback
    )

    if let previous = keymapsByID.updateValue(keymap, forKey: keymap.id) {
      if let shortcutManager {
        previous.deactivate(with: shortcutManager)
      }
    }

    if let shortcutManager {
      keymap.activate(with: shortcutManager)
    }

    return keymap
  }

  func removeKeymap(id: String) {
    guard let keymap = keymapsByID.removeValue(forKey: id) else { return }

    if let shortcutManager {
      keymap.deactivate(with: shortcutManager)
    }
  }

  func resetKeymaps() {
    let keymaps = Array(keymapsByID.values)
    keymapsByID.removeAll()

    if let shortcutManager {
      for keymap in keymaps {
        keymap.deactivate(with: shortcutManager)
      }
    }
  }

  @discardableResult
  func registerEvent(_ event: String, callback: JSValue) -> Event {
    guard let eventType = EventType(rawValue: event) else {
      log("unknown event type: \(event)", level: .error)
      return Event(event: event)
    }

    let listener = Event(event: event, callback: callback)
    listenersByEvent[eventType, default: []].append(listener)

    return listener
  }

  func removeEvent(_ event: String) {
    guard let eventType = EventType(rawValue: event) else { return }

    listenersByEvent.removeValue(forKey: eventType)
  }

  func resetEvents() {
    listenersByEvent.removeAll()
  }

  func callbacks(for event: EventType) -> [Event] {
    listenersByEvent[event] ?? []
  }

  func activeListenerCount(for event: EventType) -> Int {
    callbacks(for: event).count
  }
}

final class ConfigManager {
  static func resolvePrimaryPath(
    paths: [String] = primaryPaths,
    fileSystem: ConfigFileSystem = .live
  ) -> String {
    ConfigPathResolver.live.resolvePrimaryPath(paths, fileSystem)
  }

  private let fileSystem: ConfigFileSystem
  private let executor: ConfigExecutor
  private let fileWatcher: ConfigFileWatcher
  private let fileMonitorSetup: (ConfigManager) throws -> Void
  private let sessionStore: ConfigSessionStore
  private let shortcutManager: ShortcutManager

  private var path: String
  private var fileSystemSource: DispatchSourceFileSystemObject?
  private let fileMonitorQueue = DispatchQueue(label: "dev.tombell.stark.config")

  init(
    shortcutManager: ShortcutManager = ShortcutManager(),
    fileSystem: ConfigFileSystem = .live,
    executor: ConfigExecutor? = nil,
    path: String? = nil,
    pathResolver: ConfigPathResolver = .live,
    fileWatcher: ConfigFileWatcher = .live,
    sessionStore: ConfigSessionStore = .shared,
    fileMonitorSetup: ((ConfigManager) throws -> Void)? = nil
  ) {
    let runtimeFactory = ScriptRuntimeFactory.live()
    let scriptExecutor = ConfigScriptExecutor.live

    self.shortcutManager = shortcutManager
    self.fileSystem = fileSystem
    self.sessionStore = sessionStore
    self.executor =
      executor
      ?? ConfigExecutor(
        createContext: runtimeFactory.createContext,
        executeScript: scriptExecutor.executeScript
      )
    self.fileWatcher = fileWatcher
    self.path = path ?? pathResolver.resolvePrimaryPath(primaryPaths, fileSystem)
    self.fileMonitorSetup =
      fileMonitorSetup ?? { manager in
        try manager.setupFileMonitor()
      }
  }

  func start() -> Result<Void, Error> {
    do {
      try performLoad()
      try fileMonitorSetup(self)
      return .success(())
    } catch {
      return .failure(error)
    }
  }

  func stop() {
    fileSystemSource?.cancel()
    fileSystemSource = nil

    shortcutManager.stop()
    shortcutManager.reset()

    sessionStore.replace(with: nil)?.deactivate()
  }

  func load() -> Result<Void, Error> {
    do {
      try performLoad()
      return .success(())
    } catch {
      return .failure(error)
    }
  }

  func readConfigScript() -> Result<String, Error> {
    do {
      return .success(try readConfigScriptOrThrow())
    } catch {
      return .failure(error)
    }
  }

  private func performLoad() throws {
    let session = ConfigSession()
    let context = try executor.createContext(session)

    try executeConfig(in: session, context: context)
    apply(session)
  }

  private func executeConfig(in session: ConfigSession, context: JSContext) throws {
    let scriptContents = try readConfigScriptOrThrow()
    try executor.executeScript(session, context, scriptContents)
  }

  private func apply(_ session: ConfigSession) {
    shortcutManager.stop()
    shortcutManager.reset()

    let previousSession = sessionStore.replace(with: session)
    previousSession?.deactivate()

    session.activate(with: shortcutManager)
    shortcutManager.start()
  }

  private func readConfigScriptOrThrow() throws -> String {
    if !fileSystem.fileExists(path) {
      throw FileError.notFound(path)
    }

    guard let scriptContents = fileSystem.readFile(path) else {
      throw FileError.readFailed("could not read file \(path)")
    }

    return scriptContents
  }

  private func setupFileMonitor() throws {
    switch fileWatcher.startMonitoring(path, fileMonitorQueue, handleFileWatchReload) {
    case .success(let source):
      fileSystemSource = source
    case .failure(let error):
      throw error
    }
  }

  private func reloadConfig() {
    let reload = {
      log("config file changed, reloading...", level: .info)

      switch self.load() {
      case .success:
        break
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

    do {
      try fileMonitorSetup(self)
    } catch {
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
