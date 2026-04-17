import AppKit
import Sentry

protocol StarkProcessManaging {
  func start() -> Result<Void, AXError>
}

protocol StarkWindowManaging {
  func start()
}

protocol StarkConfigManaging {
  func start() -> Result<Void, Error>
  func stop()
}

protocol StarkStatusItemManaging {
  func setup()
}

struct StarkRuntimeEnvironment {
  static let live = StarkRuntimeEnvironment(
    isDevelopmentBuild: {
      #if DEBUG
        true
      #else
        false
      #endif
    },
    sentryDSN: { Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String },
    startSentry: { dsn in
      SentrySDK.start { options in
        options.dsn = dsn
        options.enableAppHangTracking = false
      }
    },
    askForAccessibility: {
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
      return AXIsProcessTrustedWithOptions(options as CFDictionary?)
    },
    canListenToKeyboardEvents: {
      CGPreflightListenEventAccess()
    },
    terminateApplication: {
      NSApplication.shared.terminate(nil)
    },
    writeLog: { message, level in
      log(message, level: level)
    }
  )

  var isDevelopmentBuild: () -> Bool
  var sentryDSN: () -> String?
  var startSentry: (String) -> Void
  var askForAccessibility: () -> Bool
  var canListenToKeyboardEvents: () -> Bool
  var terminateApplication: () -> Void
  var writeLog: (String, LogLevel) -> Void
}

final class StarkRuntime {
  private let environment: StarkRuntimeEnvironment
  private let processManager: StarkProcessManaging
  private let windowManager: StarkWindowManaging
  private let configManager: StarkConfigManaging
  private let statusItem: StarkStatusItemManaging

  init(
    environment: StarkRuntimeEnvironment = .live,
    processManager: StarkProcessManaging = ProcessManager.shared,
    windowManager: StarkWindowManaging = WindowManager.shared,
    shortcutManager: ShortcutManager = ShortcutManager(),
    configManager: StarkConfigManaging? = nil,
    statusItem: StarkStatusItemManaging = StarkStatusItem()
  ) {
    self.environment = environment
    self.processManager = processManager
    self.windowManager = windowManager
    self.configManager = configManager ?? ConfigManager(shortcutManager: shortcutManager)
    self.statusItem = statusItem
  }

  func start() {
    do {
      try performStart()
    } catch {
      environment.writeLog("\(error)", .error)
    }
  }

  func stop() {
    configManager.stop()
  }

  private func performStart() throws {
    if !environment.isDevelopmentBuild(), let dsn = environment.sentryDSN() {
      environment.startSentry(dsn)
    }

    guard environment.askForAccessibility() else {
      environment.terminateApplication()
      return
    }

    if !environment.canListenToKeyboardEvents() {
      environment.writeLog(
        "keyboard monitoring permission is not granted; global shortcuts are disabled",
        .error
      )
    }

    try startProcessManager()
    windowManager.start()
    try startConfigManager()
    statusItem.setup()
  }

  private func startProcessManager() throws {
    switch processManager.start() {
    case .success:
      break
    case .failure(let error):
      throw RuntimeStartupError.processManager(error)
    }
  }

  private func startConfigManager() throws {
    switch configManager.start() {
    case .success:
      break
    case .failure(let error):
      throw RuntimeStartupError.configManager(error)
    }
  }
}

private enum RuntimeStartupError: Error, CustomStringConvertible {
  case processManager(AXError)
  case configManager(Error)

  var description: String {
    switch self {
    case .processManager(let error):
      "could not start process manager: \(error)"
    case .configManager(let error):
      "could not start config manager: \(error)"
    }
  }
}

extension ProcessManager: StarkProcessManaging {}
extension WindowManager: StarkWindowManaging {}
extension ConfigManager: StarkConfigManaging {}
extension StarkStatusItem: StarkStatusItemManaging {}
