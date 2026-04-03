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

    EventManager.shared.post(event: .spaceChanged, with: Space.active())
    spinMainRunLoop()

    #expect(Event.activeListenerCount(for: .spaceChanged) == 1)
  }

  @Test func spaceChangedIgnoresUnexpectedPayloads() throws {
    resetState()
    defer { resetState() }

    _ = Event.on("spaceChanged", try callback())
    #expect(Event.activeListenerCount(for: .spaceChanged) == 1)

    EventManager.shared.post(event: .spaceChanged, with: "not-a-space")
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
