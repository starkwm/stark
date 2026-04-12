import Foundation
import Testing

@testable import Stark

@Suite(.serialized) struct StarkRuntimeTests {
  @Test func startInitializesServicesInCurrentOrder() {
    let recorder = RuntimeCallRecorder()
    let processManager = RecordingProcessManager(recorder: recorder, result: .success(()))
    let windowManager = RecordingWindowManager(recorder: recorder)
    let configManager = RecordingConfigManager(recorder: recorder, startResult: .success(()))
    let statusItem = RecordingStatusItem(recorder: recorder)
    var loggedMessages = [LoggedMessage]()

    let runtime = StarkRuntime(
      environment: StarkRuntimeEnvironment(
        isDevelopmentBuild: { false },
        sentryDSN: { "dsn" },
        startSentry: { _ in recorder.record("startSentry") },
        askForAccessibility: {
          recorder.record("askForAccessibility")
          return true
        },
        terminateApplication: { recorder.record("terminateApplication") },
        writeLog: { message, level in
          loggedMessages.append(LoggedMessage(message: message, level: level))
        }
      ),
      processManager: processManager,
      windowManager: windowManager,
      configManager: configManager,
      statusItem: statusItem
    )

    runtime.start()

    #expect(
      recorder.events == [
        "startSentry",
        "askForAccessibility",
        "process.start",
        "window.start",
        "config.start",
        "statusItem.setup",
      ]
    )
    #expect(loggedMessages.isEmpty)
  }

  @Test func startSkipsSentryInDevelopmentBuilds() {
    let recorder = RuntimeCallRecorder()
    let runtime = StarkRuntime(
      environment: StarkRuntimeEnvironment(
        isDevelopmentBuild: { true },
        sentryDSN: { "dsn" },
        startSentry: { _ in recorder.record("startSentry") },
        askForAccessibility: {
          recorder.record("askForAccessibility")
          return true
        },
        terminateApplication: { recorder.record("terminateApplication") },
        writeLog: { _, _ in recorder.record("writeLog") }
      ),
      processManager: RecordingProcessManager(recorder: recorder, result: .success(())),
      windowManager: RecordingWindowManager(recorder: recorder),
      configManager: RecordingConfigManager(recorder: recorder, startResult: .success(())),
      statusItem: RecordingStatusItem(recorder: recorder)
    )

    runtime.start()

    #expect(
      recorder.events == [
        "askForAccessibility",
        "process.start",
        "window.start",
        "config.start",
        "statusItem.setup",
      ]
    )
  }

  @Test func startTerminatesApplicationWhenAccessibilityIsDenied() {
    let recorder = RuntimeCallRecorder()
    let runtime = StarkRuntime(
      environment: StarkRuntimeEnvironment(
        isDevelopmentBuild: { false },
        sentryDSN: { "dsn" },
        startSentry: { _ in recorder.record("startSentry") },
        askForAccessibility: {
          recorder.record("askForAccessibility")
          return false
        },
        terminateApplication: { recorder.record("terminateApplication") },
        writeLog: { _, _ in recorder.record("writeLog") }
      ),
      processManager: RecordingProcessManager(recorder: recorder, result: .success(())),
      windowManager: RecordingWindowManager(recorder: recorder),
      configManager: RecordingConfigManager(recorder: recorder, startResult: .success(())),
      statusItem: RecordingStatusItem(recorder: recorder)
    )

    runtime.start()

    #expect(
      recorder.events == [
        "startSentry",
        "askForAccessibility",
        "terminateApplication",
      ]
    )
  }

  @Test func startStopsAfterProcessManagerFailure() {
    let recorder = RuntimeCallRecorder()
    var loggedMessages = [LoggedMessage]()
    let runtime = StarkRuntime(
      environment: StarkRuntimeEnvironment(
        isDevelopmentBuild: { false },
        sentryDSN: { nil },
        startSentry: { _ in recorder.record("startSentry") },
        askForAccessibility: {
          recorder.record("askForAccessibility")
          return true
        },
        terminateApplication: { recorder.record("terminateApplication") },
        writeLog: { message, level in
          loggedMessages.append(LoggedMessage(message: message, level: level))
        }
      ),
      processManager: RecordingProcessManager(
        recorder: recorder,
        result: .failure(.accessFailed("boom"))
      ),
      windowManager: RecordingWindowManager(recorder: recorder),
      configManager: RecordingConfigManager(recorder: recorder, startResult: .success(())),
      statusItem: RecordingStatusItem(recorder: recorder)
    )

    runtime.start()

    #expect(
      recorder.events == [
        "askForAccessibility",
        "process.start",
      ]
    )
    #expect(loggedMessages.count == 1)
    #expect(loggedMessages[0].level == .error)
    #expect(loggedMessages[0].message.contains("could not start process manager"))
    #expect(loggedMessages[0].message.contains("boom"))
  }

  @Test func startStopsAfterConfigManagerFailure() {
    let recorder = RuntimeCallRecorder()
    var loggedMessages = [LoggedMessage]()
    let runtime = StarkRuntime(
      environment: StarkRuntimeEnvironment(
        isDevelopmentBuild: { false },
        sentryDSN: { nil },
        startSentry: { _ in recorder.record("startSentry") },
        askForAccessibility: {
          recorder.record("askForAccessibility")
          return true
        },
        terminateApplication: { recorder.record("terminateApplication") },
        writeLog: { message, level in
          loggedMessages.append(LoggedMessage(message: message, level: level))
        }
      ),
      processManager: RecordingProcessManager(recorder: recorder, result: .success(())),
      windowManager: RecordingWindowManager(recorder: recorder),
      configManager: RecordingConfigManager(
        recorder: recorder,
        startResult: .failure(RuntimeTestError.configStartFailed)
      ),
      statusItem: RecordingStatusItem(recorder: recorder)
    )

    runtime.start()

    #expect(
      recorder.events == [
        "askForAccessibility",
        "process.start",
        "window.start",
        "config.start",
      ]
    )
    #expect(loggedMessages.count == 1)
    #expect(loggedMessages[0].level == .error)
    #expect(loggedMessages[0].message.contains("could not start config manager"))
    #expect(loggedMessages[0].message.contains("configStartFailed"))
  }

  @Test func stopStopsConfigManager() {
    let recorder = RuntimeCallRecorder()
    let configManager = RecordingConfigManager(recorder: recorder, startResult: .success(()))
    let runtime = StarkRuntime(
      environment: StarkRuntimeEnvironment(
        isDevelopmentBuild: { false },
        sentryDSN: { nil },
        startSentry: { _ in recorder.record("startSentry") },
        askForAccessibility: {
          recorder.record("askForAccessibility")
          return true
        },
        terminateApplication: { recorder.record("terminateApplication") },
        writeLog: { _, _ in recorder.record("writeLog") }
      ),
      processManager: RecordingProcessManager(recorder: recorder, result: .success(())),
      windowManager: RecordingWindowManager(recorder: recorder),
      configManager: configManager,
      statusItem: RecordingStatusItem(recorder: recorder)
    )

    runtime.stop()

    #expect(recorder.events == ["config.stop"])
  }

  @Test func appDelegateStartsAndStopsInjectedRuntime() {
    let runtime = RecordingRuntime()
    let delegate = AppDelegate(makeRuntime: { runtime })

    delegate.applicationDidFinishLaunching(Notification(name: .init("didFinishLaunching")))
    delegate.applicationWillTerminate(Notification(name: .init("willTerminate")))

    #expect(runtime.startCallCount == 1)
    #expect(runtime.stopCallCount == 1)
  }
}

private final class RuntimeCallRecorder {
  private(set) var events = [String]()

  func record(_ event: String) {
    events.append(event)
  }
}

private struct LoggedMessage {
  let message: String
  let level: LogLevel
}

private final class RecordingProcessManager: StarkProcessManaging {
  private let recorder: RuntimeCallRecorder
  private let result: Result<Void, AXError>

  init(recorder: RuntimeCallRecorder, result: Result<Void, AXError>) {
    self.recorder = recorder
    self.result = result
  }

  func start() -> Result<Void, AXError> {
    recorder.record("process.start")
    return result
  }
}

private final class RecordingWindowManager: StarkWindowManaging {
  private let recorder: RuntimeCallRecorder

  init(recorder: RuntimeCallRecorder) {
    self.recorder = recorder
  }

  func start() {
    recorder.record("window.start")
  }
}

private final class RecordingConfigManager: StarkConfigManaging {
  private let recorder: RuntimeCallRecorder
  private let startResult: Result<Void, Error>

  init(recorder: RuntimeCallRecorder, startResult: Result<Void, Error>) {
    self.recorder = recorder
    self.startResult = startResult
  }

  func start() -> Result<Void, Error> {
    recorder.record("config.start")
    return startResult
  }

  func stop() {
    recorder.record("config.stop")
  }
}

private final class RecordingStatusItem: StarkStatusItemManaging {
  private let recorder: RuntimeCallRecorder

  init(recorder: RuntimeCallRecorder) {
    self.recorder = recorder
  }

  func setup() {
    recorder.record("statusItem.setup")
  }
}

private final class RecordingRuntime: StarkRuntimeType {
  private(set) var startCallCount = 0
  private(set) var stopCallCount = 0

  func start() {
    startCallCount += 1
  }

  func stop() {
    stopCallCount += 1
  }
}

private enum RuntimeTestError: Error {
  case configStartFailed
}
