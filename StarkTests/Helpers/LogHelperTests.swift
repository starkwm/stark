import Foundation
import Testing

@testable import Stark

private final class LogRecorder {
  var appendCalls = [(String, String)]()
  var writeCalls = [(String, String)]()
  var consoleMessages = [String]()
}

@Suite(.serialized) struct LogHelperTests {
  @Test func writeCreatesNewFileWhenAppendFails() {
    let recorder = LogRecorder()
    let helper = LogHelper(
      fileSystem: LogFileSystem(
        homeDirectory: { "/tmp/home" },
        append: { url, data in
          recorder.appendCalls.append((url.path, String(decoding: data, as: UTF8.self)))
          return false
        },
        write: { url, data in
          recorder.writeCalls.append((url.path, String(decoding: data, as: UTF8.self)))
        }
      )
    )

    helper.write("hello")

    #expect(recorder.appendCalls.count == 1)
    #expect(recorder.appendCalls[0].0 == "/tmp/home/.stark.log")
    #expect(recorder.appendCalls[0].1 == "hello")
    #expect(recorder.writeCalls.count == 1)
    #expect(recorder.writeCalls[0].0 == "/tmp/home/.stark.log")
    #expect(recorder.writeCalls[0].1 == "hello")
  }

  @Test func writeAppendsWhenFileExists() {
    let recorder = LogRecorder()
    let helper = LogHelper(
      fileSystem: LogFileSystem(
        homeDirectory: { "/tmp/home" },
        append: { url, data in
          recorder.appendCalls.append((url.path, String(decoding: data, as: UTF8.self)))
          return true
        },
        write: { url, data in
          recorder.writeCalls.append((url.path, String(decoding: data, as: UTF8.self)))
        }
      )
    )

    helper.write("hello")

    #expect(recorder.appendCalls.count == 1)
    #expect(recorder.appendCalls[0].0 == "/tmp/home/.stark.log")
    #expect(recorder.appendCalls[0].1 == "hello")
    #expect(recorder.writeCalls.isEmpty)
  }

  @Test func logWritesThroughLoggerWhenEnabled() {
    let recorder = LogRecorder()
    let previousLogger = logger
    let previousDateProvider = logDateProvider
    let previousEnabledProvider = logEnabledProvider
    let previousConsoleWriter = logConsoleWriter
    defer {
      logger = previousLogger
      logDateProvider = previousDateProvider
      logEnabledProvider = previousEnabledProvider
      logConsoleWriter = previousConsoleWriter
    }

    logger = LogHelper(
      fileSystem: LogFileSystem(
        homeDirectory: { "/tmp/home" },
        append: { _, _ in false },
        write: { url, data in
          recorder.writeCalls.append((url.path, String(decoding: data, as: UTF8.self)))
        }
      )
    )
    logDateProvider = { "2026-04-02T12:00:00Z" }
    logEnabledProvider = { true }
    logConsoleWriter = { recorder.consoleMessages.append($0) }

    log("message", level: .warn)

    #expect(recorder.consoleMessages.isEmpty)
    #expect(!recorder.writeCalls.isEmpty)
    #expect(Set(recorder.writeCalls.map(\.0)) == ["/tmp/home/.stark.log"])
    #expect(recorder.writeCalls.map(\.1).joined() == "2026-04-02T12:00:00Z WARN: message\n")
  }

  @Test func logUsesDefaultDebugLevelAndWritesTrailingNewlineWhenEnabled() {
    let recorder = LogRecorder()
    let previousLogger = logger
    let previousDateProvider = logDateProvider
    let previousEnabledProvider = logEnabledProvider
    let previousConsoleWriter = logConsoleWriter
    defer {
      logger = previousLogger
      logDateProvider = previousDateProvider
      logEnabledProvider = previousEnabledProvider
      logConsoleWriter = previousConsoleWriter
    }

    logger = LogHelper(
      fileSystem: LogFileSystem(
        homeDirectory: { "/tmp/home" },
        append: { _, _ in false },
        write: { url, data in
          recorder.writeCalls.append((url.path, String(decoding: data, as: UTF8.self)))
        }
      )
    )
    logDateProvider = { "2026-04-02T12:00:01Z" }
    logEnabledProvider = { true }
    logConsoleWriter = { recorder.consoleMessages.append($0) }

    log("debug message")

    #expect(recorder.consoleMessages.isEmpty)
    #expect(recorder.writeCalls.map(\.1).joined() == "2026-04-02T12:00:01Z DEBUG: debug message\n")
  }

  @Test func logWritesToConsoleWhenDisabled() {
    let recorder = LogRecorder()
    let previousLogger = logger
    let previousDateProvider = logDateProvider
    let previousEnabledProvider = logEnabledProvider
    let previousConsoleWriter = logConsoleWriter
    defer {
      logger = previousLogger
      logDateProvider = previousDateProvider
      logEnabledProvider = previousEnabledProvider
      logConsoleWriter = previousConsoleWriter
    }

    logger = LogHelper(
      fileSystem: LogFileSystem(
        homeDirectory: { "/tmp/home" },
        append: { _, _ in true },
        write: { _, _ in }
      )
    )
    logDateProvider = { "2026-04-02T12:00:00Z" }
    logEnabledProvider = { false }
    logConsoleWriter = { recorder.consoleMessages.append($0) }

    log("message", level: .error)

    #expect(recorder.consoleMessages == ["2026-04-02T12:00:00Z ERROR: message"])
  }

  @Test func logWritesInfoMessagesToConsoleWithoutTrailingNewline() {
    let recorder = LogRecorder()
    let previousLogger = logger
    let previousDateProvider = logDateProvider
    let previousEnabledProvider = logEnabledProvider
    let previousConsoleWriter = logConsoleWriter
    defer {
      logger = previousLogger
      logDateProvider = previousDateProvider
      logEnabledProvider = previousEnabledProvider
      logConsoleWriter = previousConsoleWriter
    }

    logger = LogHelper(
      fileSystem: LogFileSystem(
        homeDirectory: { "/tmp/home" },
        append: { _, _ in true },
        write: { _, _ in }
      )
    )
    logDateProvider = { "2026-04-02T12:00:02Z" }
    logEnabledProvider = { false }
    logConsoleWriter = { recorder.consoleMessages.append($0) }

    log("info message", level: .info)

    #expect(recorder.consoleMessages == ["2026-04-02T12:00:02Z INFO: info message"])
  }
}
