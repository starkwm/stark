import Foundation
import JavaScriptCore
import Testing

@testable import Stark

@Suite(.serialized) struct EventManagerTests {
  @Test func spaceChangedProcessesValidPayloadWithoutMutatingListenerState() throws {
    resetState()
    defer { resetState() }

    _ = Event.on("spaceChanged", try callback())

    #expect(Event.activeListenerCount(for: .spaceChanged) == 1)

    EventManager.shared.post(.space(.changed(Space.active())))
    spinMainRunLoop()

    #expect(Event.activeListenerCount(for: .spaceChanged) == 1)
  }

  @Test func typedRuntimeEventExposesUnderlyingEventType() {
    let event = RuntimeEvent.space(.changed(Space.active()))

    #expect(event.type == .spaceChanged)
  }

  @Test func windowEventExposesUnderlyingEventType() {
    let event = RuntimeEvent.window(.focused(42))

    #expect(event.type == .windowFocused)
  }

  @Test func createdWindowEventExposesUnderlyingEventType() {
    let event = RuntimeEvent.window(.created(123, 42))

    #expect(event.type == .windowCreated)
  }

  @Test func applicationEventExposesUnderlyingEventType() {
    let process = Stark.Process(
      psn: ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: 1),
      pid: 1,
      name: "Test"
    )

    let event = RuntimeEvent.application(.launched(process))

    #expect(event.type == .applicationLaunched)
  }

  @Test func spaceChangedWithTypedEventKeepsListenerStateStable() throws {
    resetState()
    defer { resetState() }

    _ = Event.on("spaceChanged", try callback())
    #expect(Event.activeListenerCount(for: .spaceChanged) == 1)

    EventManager.shared.post(.space(.changed(Space.active())))
    spinMainRunLoop()

    #expect(Event.activeListenerCount(for: .spaceChanged) == 1)
  }

  private func resetState() {
    Event.resetForTesting()
  }

  private func callback() throws -> JSValue {
    guard let context = JSContext() else {
      throw CallbackError.contextCreationFailed
    }

    guard let callback = context.evaluateScript("(() => {})") else {
      throw CallbackError.callbackCreationFailed
    }

    return callback
  }

  private func spinMainRunLoop(iterations: Int = 3, duration: TimeInterval = 0.01) {
    for _ in 0..<iterations {
      RunLoop.main.run(until: Date().addingTimeInterval(duration))
    }
  }
}

private enum CallbackError: Error {
  case contextCreationFailed
  case callbackCreationFailed
}
