import Foundation
import Testing

@testable import Stark

@Suite(.serialized) struct LaunchAgentHelperTests {
  @Test func resolvesLaunchAgentDirectory() {
    useEnvironment(libraryDirectory: URL(fileURLWithPath: "/tmp/Library"))
    defer { resetState() }

    #expect(LaunchAgentHelper.launchAgentDirectory()?.path == "/tmp/Library/LaunchAgents")
  }

  @Test func resolvesLaunchAgentFileFromBundleIdentifier() {
    useEnvironment(
      libraryDirectory: URL(fileURLWithPath: "/tmp/Library"),
      bundleIdentifier: "dev.tombell.Stark"
    )
    defer { resetState() }

    #expect(LaunchAgentHelper.launchAgentFile()?.path == "/tmp/Library/LaunchAgents/dev.tombell.Stark.plist")
  }

  @Test func enabledReturnsReachabilityForLaunchAgentFile() {
    let recorder = Recorder()
    useEnvironment(
      libraryDirectory: URL(fileURLWithPath: "/tmp/Library"),
      bundleIdentifier: "dev.tombell.Stark",
      isReachable: { url in
        recorder.reachablePaths.append(url.path)
        return true
      }
    )
    defer { resetState() }

    #expect(LaunchAgentHelper.enabled())
    #expect(recorder.reachablePaths == ["/tmp/Library/LaunchAgents/dev.tombell.Stark.plist"])
  }

  @Test func addCreatesDirectoryWhenMissingAndWritesExpectedPlist() {
    let recorder = Recorder()
    useEnvironment(
      libraryDirectory: URL(fileURLWithPath: "/tmp/Library"),
      bundleIdentifier: "dev.tombell.Stark",
      executablePath: "/Applications/Stark.app/Contents/MacOS/Stark",
      isReachable: { _ in false },
      createDirectory: { url in recorder.createdDirectories.append(url.path) },
      writePlist: { plist, url in
        recorder.writtenPlist = plist
        recorder.writtenPath = url.path
      }
    )
    defer { resetState() }

    LaunchAgentHelper.add()

    #expect(recorder.createdDirectories == ["/tmp/Library/LaunchAgents"])
    #expect(recorder.writtenPath == "/tmp/Library/LaunchAgents/dev.tombell.Stark.plist")
    #expect(recorder.writtenPlist.map { Set($0.keys) } == ["Label", "Program", "RunAtLoad"])
    #expect(recorder.writtenPlist?["Label"] as? String == "dev.tombell.Stark")
    #expect(recorder.writtenPlist?["Program"] as? String == "/Applications/Stark.app/Contents/MacOS/Stark")
    #expect(recorder.writtenPlist?["RunAtLoad"] as? Bool == true)
  }

  @Test func addSkipsDirectoryCreationWhenAlreadyReachable() {
    let recorder = Recorder()
    useEnvironment(
      libraryDirectory: URL(fileURLWithPath: "/tmp/Library"),
      bundleIdentifier: "dev.tombell.Stark",
      executablePath: "/Applications/Stark.app/Contents/MacOS/Stark",
      isReachable: { _ in true },
      createDirectory: { url in recorder.createdDirectories.append(url.path) },
      writePlist: { _, _ in }
    )
    defer { resetState() }

    LaunchAgentHelper.add()

    #expect(recorder.createdDirectories.isEmpty)
  }

  @Test func removeDeletesLaunchAgentFile() {
    let recorder = Recorder()
    useEnvironment(
      libraryDirectory: URL(fileURLWithPath: "/tmp/Library"),
      bundleIdentifier: "dev.tombell.Stark",
      removeItem: { url in recorder.removedPaths.append(url.path) }
    )
    defer { resetState() }

    LaunchAgentHelper.remove()

    #expect(recorder.removedPaths == ["/tmp/Library/LaunchAgents/dev.tombell.Stark.plist"])
  }

  @Test func missingLibraryDirectoryReturnsNilPathsAndDisabledFalse() {
    useEnvironment(libraryDirectory: nil)
    defer { resetState() }

    #expect(LaunchAgentHelper.launchAgentDirectory() == nil)
    #expect(LaunchAgentHelper.launchAgentFile() == nil)
    #expect(!LaunchAgentHelper.enabled())
  }

  @Test func missingBundleIdentifierMakesAddAndRemoveNoOps() {
    let recorder = Recorder()
    useEnvironment(
      libraryDirectory: URL(fileURLWithPath: "/tmp/Library"),
      bundleIdentifier: nil,
      createDirectory: { url in recorder.createdDirectories.append(url.path) },
      writePlist: { _, url in recorder.writtenPath = url.path },
      removeItem: { url in recorder.removedPaths.append(url.path) }
    )
    defer { resetState() }

    LaunchAgentHelper.add()
    LaunchAgentHelper.remove()

    #expect(LaunchAgentHelper.launchAgentFile() == nil)
    #expect(recorder.createdDirectories.isEmpty)
    #expect(recorder.writtenPath == nil)
    #expect(recorder.removedPaths.isEmpty)
  }

  @Test func missingExecutablePathSkipsPlistWriting() {
    let recorder = Recorder()
    useEnvironment(
      libraryDirectory: URL(fileURLWithPath: "/tmp/Library"),
      bundleIdentifier: "dev.tombell.Stark",
      executablePath: nil,
      isReachable: { _ in true },
      writePlist: { _, url in recorder.writtenPath = url.path }
    )
    defer { resetState() }

    LaunchAgentHelper.add()

    #expect(recorder.writtenPath == nil)
  }

  @Test func removeDoesNothingWhenLaunchAgentFileCannotBeResolved() {
    let recorder = Recorder()
    useEnvironment(
      libraryDirectory: URL(fileURLWithPath: "/tmp/Library"),
      bundleIdentifier: nil,
      removeItem: { url in recorder.removedPaths.append(url.path) }
    )
    defer { resetState() }

    LaunchAgentHelper.remove()

    #expect(recorder.removedPaths.isEmpty)
  }

  private func useEnvironment(
    libraryDirectory: URL? = URL(fileURLWithPath: "/tmp/Library"),
    bundleIdentifier: String? = "dev.tombell.Stark",
    executablePath: String? = "/Applications/Stark.app/Contents/MacOS/Stark",
    isReachable: @escaping (URL) -> Bool = { _ in false },
    createDirectory: @escaping (URL) -> Void = { _ in },
    writePlist: @escaping ([String: Any], URL) -> Void = { _, _ in },
    removeItem: @escaping (URL) -> Void = { _ in }
  ) {
    LaunchAgentHelper.useEnvironment(
      LaunchAgentEnvironment(
        libraryDirectory: { libraryDirectory },
        bundleIdentifier: { bundleIdentifier },
        executablePath: { executablePath },
        isReachable: isReachable,
        createDirectory: createDirectory,
        writePlist: writePlist,
        removeItem: removeItem
      )
    )
  }

  private func resetState() {
    LaunchAgentHelper.resetForTesting()
  }
}

private final class Recorder {
  var reachablePaths = [String]()
  var createdDirectories = [String]()
  var removedPaths = [String]()
  var writtenPath: String?
  var writtenPlist: [String: Any]?
}
