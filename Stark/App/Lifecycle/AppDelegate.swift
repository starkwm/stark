import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let shouldStartRuntime = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil

  private var runtime: StarkRuntime?

  func applicationDidFinishLaunching(_: Notification) {
    guard shouldStartRuntime else { return }

    let runtime = StarkRuntime()
    self.runtime = runtime
    runtime.start()
  }

  func applicationWillTerminate(_: Notification) {
    runtime?.stop()
  }
}
