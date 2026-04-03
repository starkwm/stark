import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
  private let makeRuntime: () -> StarkRuntimeType
  private var runtime: StarkRuntimeType?

  override init() {
    makeRuntime = { StarkRuntime.live() }
    super.init()
  }

  init(makeRuntime: @escaping () -> StarkRuntimeType) {
    self.makeRuntime = makeRuntime
    super.init()
  }

  func applicationDidFinishLaunching(_: Notification) {
    let runtime = makeRuntime()
    self.runtime = runtime
    runtime.start()
  }

  func applicationWillTerminate(_: Notification) {
    runtime?.stop()
  }
}
