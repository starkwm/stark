import JavaScriptCore
import Testing

@testable import Stark

@Suite(.serialized)
struct EventTests {
  @Test
  func unknownEventsAreNotRegistered() throws {
    let session = ConfigSession()
    let listener = session.eventBridge.on("notReal", try callback())

    #expect(listener.event == "notReal")
    #expect(session.activeListenerCount(for: .windowFocused) == 0)
  }

  @Test
  func onAndOffManageActiveListeners() throws {
    let session = ConfigSession()

    _ = session.eventBridge.on("windowFocused", try callback())
    _ = session.eventBridge.on("windowFocused", try callback())

    #expect(session.activeListenerCount(for: .windowFocused) == 2)

    session.eventBridge.off("windowFocused")

    #expect(session.activeListenerCount(for: .windowFocused) == 0)
  }

  @Test
  func resetClearsAllActiveListeners() throws {
    let session = ConfigSession()

    _ = session.eventBridge.on("windowFocused", try callback())
    _ = session.eventBridge.on("windowMoved", try callback())

    session.eventBridge.reset()

    #expect(session.activeListenerCount(for: .windowFocused) == 0)
    #expect(session.activeListenerCount(for: .windowMoved) == 0)
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
}

private enum CallbackError: Error {
  case contextCreationFailed
  case callbackCreationFailed
}
