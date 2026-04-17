import AppKit
import Sentry

final class StarkRuntime {
  private let processManager = ProcessManager.shared
  private let windowManager = WindowManager.shared
  private let configManager: ConfigManager
  private let statusItem = StarkStatusItem()

  init() {
    configManager = ConfigManager(shortcutManager: ShortcutManager())
  }

  func start() {
    do {
      try performStart()
    } catch {
      log("\(error)", level: .error)
    }
  }

  func stop() {
    configManager.stop()
  }

  private func performStart() throws {
    #if !DEBUG
      if let dsn = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String {
        SentrySDK.start { options in
          options.dsn = dsn
          options.enableAppHangTracking = false
        }
      }
    #endif

    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    guard AXIsProcessTrustedWithOptions(options as CFDictionary?) else {
      NSApplication.shared.terminate(nil)
      return
    }

    if !CGPreflightListenEventAccess() {
      log(
        "keyboard monitoring permission is not granted; global shortcuts are disabled",
        level: .error
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
