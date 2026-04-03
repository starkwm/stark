import AppKit
import Sentry

protocol StarkRuntimeType: AnyObject {
  /// Starts all runtime services required for the app to function.
  func start()
  /// Stops runtime services that hold external state or observers.
  func stop()
}

protocol StarkProcessManaging {
  /// Starts process discovery and lifecycle monitoring.
  func start() -> Result<Void, AXError>
}

protocol StarkWindowManaging {
  /// Starts observing applications and windows that Stark can manage.
  func start()
}

protocol StarkConfigManaging {
  /// Loads the user configuration and begins watching it for changes.
  func start() -> Result<Void, Error>
  /// Stops configuration monitoring and associated shortcut registration.
  func stop()
}

protocol StarkStatusItemManaging {
  /// Installs the menu bar status item and its menu actions.
  func setup()
}

/// Provides platform-facing hooks used while bootstrapping Stark's long-lived services.
struct StarkRuntimeEnvironment {
  var sentryDSN: () -> String?
  var startSentry: (String) -> Void
  var askForAccessibility: () -> Bool
  var terminateApplication: () -> Void
  var writeLog: (String, LogLevel) -> Void

  static let live = StarkRuntimeEnvironment(
    sentryDSN: { Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String },
    startSentry: { dsn in
      SentrySDK.start { options in
        options.dsn = dsn
      }
    },
    askForAccessibility: {
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
      return AXIsProcessTrustedWithOptions(options as CFDictionary?)
    },
    terminateApplication: {
      NSApplication.shared.terminate(nil)
    },
    writeLog: { message, level in
      log(message, level: level)
    }
  )
}

/// Composes and coordinates startup and shutdown for Stark's runtime services.
final class StarkRuntime: StarkRuntimeType {
  private let environment: StarkRuntimeEnvironment
  private let processManager: StarkProcessManaging
  private let windowManager: StarkWindowManaging
  private let configManager: StarkConfigManaging
  private let statusItem: StarkStatusItemManaging

  init(
    environment: StarkRuntimeEnvironment = .live,
    processManager: StarkProcessManaging = ProcessManager.shared,
    windowManager: StarkWindowManaging = WindowManager.shared,
    configManager: StarkConfigManaging = ConfigManager.shared,
    statusItem: StarkStatusItemManaging = StarkStatusItem()
  ) {
    self.environment = environment
    self.processManager = processManager
    self.windowManager = windowManager
    self.configManager = configManager
    self.statusItem = statusItem
  }

  /// Builds the default runtime wired to the app's singleton services.
  static func live() -> StarkRuntime {
    StarkRuntime()
  }

  /// Boots the runtime in dependency order so each subsystem sees initialized state.
  func start() {
    if let dsn = environment.sentryDSN() {
      environment.startSentry(dsn)
    }

    guard environment.askForAccessibility() else {
      environment.terminateApplication()
      return
    }

    switch processManager.start() {
    case .success:
      break
    case .failure(let error):
      environment.writeLog("could not start process manager: \(error)", .error)
      return
    }

    windowManager.start()

    switch configManager.start() {
    case .success:
      break
    case .failure(let error):
      environment.writeLog("could not start config manager: \(error)", .error)
      return
    }

    statusItem.setup()
  }

  /// Stops services that keep long-lived state between app events.
  func stop() {
    configManager.stop()
  }
}

extension ProcessManager: StarkProcessManaging {}
extension WindowManager: StarkWindowManaging {}
extension ConfigManager: StarkConfigManaging {}
extension StarkStatusItem: StarkStatusItemManaging {}
