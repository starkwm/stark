import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
  private let makeRuntime: () -> StarkRuntimeType
  private var runtime: StarkRuntimeType?

  override init() {
    makeRuntime = { StarkRuntime.live() }
    super.init()
  }

  /// Allows tests to inject a custom runtime factory.
  init(makeRuntime: @escaping () -> StarkRuntimeType) {
    self.makeRuntime = makeRuntime
    super.init()
  }

  /// Creates and starts the runtime once AppKit has finished launching.
  func applicationDidFinishLaunching(_: Notification) {
    let runtime = makeRuntime()
    self.runtime = runtime
    runtime.start()
  }

  /// Stops runtime-managed services before the application terminates.
  func applicationWillTerminate(_: Notification) {
    runtime?.stop()
  }
}
