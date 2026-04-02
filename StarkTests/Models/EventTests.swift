import JavaScriptCore
import Testing

@testable import Stark

@Suite(.serialized) struct EventTests {
  @Test func unknownEventsAreNotRegistered() throws {
    resetState()
    defer { resetState() }

    let listener = Event.on("notReal", try callback())

    #expect(listener.event == "notReal")
    #expect(Event.activeListenerCount(for: .windowFocused) == 0)
  }

  @Test func onAndOffManageActiveListeners() throws {
    resetState()
    defer { resetState() }

    _ = Event.on("windowFocused", try callback())
    _ = Event.on("windowFocused", try callback())

    #expect(Event.activeListenerCount(for: .windowFocused) == 2)

    Event.off("windowFocused")

    #expect(Event.activeListenerCount(for: .windowFocused) == 0)
  }

  @Test func resetClearsAllActiveListeners() throws {
    resetState()
    defer { resetState() }

    _ = Event.on("windowFocused", try callback())
    _ = Event.on("windowMoved", try callback())

    Event.reset()

    #expect(Event.activeListenerCount(for: .windowFocused) == 0)
    #expect(Event.activeListenerCount(for: .windowMoved) == 0)
  }

  @Test func commitRecordingSwapsRecordedListenersIntoActiveState() throws {
    resetState()
    defer { resetState() }

    _ = Event.on("windowFocused", try callback())

    Event.beginRecording()
    _ = Event.on("windowMoved", try callback())
    _ = Event.on("windowMoved", try callback())

    #expect(Event.activeListenerCount(for: .windowFocused) == 1)
    #expect(Event.recordingListenerCount(for: .windowMoved) == 2)

    Event.commitRecording()

    #expect(Event.activeListenerCount(for: .windowFocused) == 0)
    #expect(Event.activeListenerCount(for: .windowMoved) == 2)
    #expect(Event.recordingListenerCount(for: .windowMoved) == 0)
  }

  @Test func discardRecordingPreservesActiveListeners() throws {
    resetState()
    defer { resetState() }

    _ = Event.on("windowFocused", try callback())

    Event.beginRecording()
    _ = Event.on("windowMoved", try callback())
    Event.discardRecording()

    #expect(Event.activeListenerCount(for: .windowFocused) == 1)
    #expect(Event.activeListenerCount(for: .windowMoved) == 0)
    #expect(Event.recordingListenerCount(for: .windowMoved) == 0)
  }

  @Test func offWithinRecordingOnlyClearsRecordedListeners() throws {
    resetState()
    defer { resetState() }

    _ = Event.on("windowFocused", try callback())

    Event.beginRecording()
    _ = Event.on("windowMoved", try callback())
    _ = Event.on("windowMoved", try callback())

    Event.off("windowMoved")

    #expect(Event.activeListenerCount(for: .windowFocused) == 1)
    #expect(Event.recordingListenerCount(for: .windowMoved) == 0)
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

  private func resetState() {
    Event.resetForTesting()
  }
}

private enum CallbackError: Error {
  case contextCreationFailed
  case callbackCreationFailed
}
