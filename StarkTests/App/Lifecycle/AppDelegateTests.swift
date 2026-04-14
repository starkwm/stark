import AppKit
import Testing

@testable import Stark

@Suite struct AppDelegateTests {
  @Test func launchStartsRuntimeWhenEnabled() {
    let runtime = RecordingRuntime()
    let delegate = AppDelegate(
      makeRuntime: { runtime },
      shouldStartRuntime: { true }
    )

    delegate.applicationDidFinishLaunching(
      Notification(name: NSApplication.didFinishLaunchingNotification)
    )

    #expect(runtime.startCallCount == 1)
    #expect(runtime.stopCallCount == 0)
  }

  @Test func launchSkipsRuntimeWhenDisabled() {
    var makeRuntimeCallCount = 0
    let delegate = AppDelegate(
      makeRuntime: {
        makeRuntimeCallCount += 1
        return RecordingRuntime()
      },
      shouldStartRuntime: { false }
    )

    delegate.applicationDidFinishLaunching(
      Notification(name: NSApplication.didFinishLaunchingNotification)
    )

    #expect(makeRuntimeCallCount == 0)
  }

  @Test func terminationStopsStartedRuntime() {
    let runtime = RecordingRuntime()
    let delegate = AppDelegate(
      makeRuntime: { runtime },
      shouldStartRuntime: { true }
    )

    delegate.applicationDidFinishLaunching(
      Notification(name: NSApplication.didFinishLaunchingNotification)
    )
    delegate.applicationWillTerminate(
      Notification(name: NSApplication.willTerminateNotification)
    )

    #expect(runtime.startCallCount == 1)
    #expect(runtime.stopCallCount == 1)
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
