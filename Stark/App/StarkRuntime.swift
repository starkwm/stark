import AppKit
import Sentry

protocol StarkRuntimeType: AnyObject {
  func start()
  func stop()
}

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

  static func live() -> StarkRuntime {
    StarkRuntime()
  }

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

  func stop() {
    configManager.stop()
  }
}

extension ProcessManager: StarkProcessManaging {}
extension WindowManager: StarkWindowManaging {}
extension ConfigManager: StarkConfigManaging {}
extension StarkStatusItem: StarkStatusItemManaging {}
