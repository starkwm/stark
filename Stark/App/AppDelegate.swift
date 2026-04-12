import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
  private let makeRuntime: () -> StarkRuntimeType
  private let shouldStartRuntime: () -> Bool
  private var runtime: StarkRuntimeType?

  override init() {
    makeRuntime = { StarkRuntime.live() }
    shouldStartRuntime = {
      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }
    super.init()
  }

  init(
    makeRuntime: @escaping () -> StarkRuntimeType,
    shouldStartRuntime: @escaping () -> Bool = { true }
  ) {
    self.makeRuntime = makeRuntime
    self.shouldStartRuntime = shouldStartRuntime
    super.init()
  }

  func applicationDidFinishLaunching(_: Notification) {
    guard shouldStartRuntime() else { return }

    let runtime = makeRuntime()
    self.runtime = runtime
    runtime.start()
  }

  func applicationWillTerminate(_: Notification) {
    runtime?.stop()
  }
}
