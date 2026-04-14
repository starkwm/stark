import JavaScriptCore

@objc protocol EventJSExport: JSExport {
  func on(_ event: String, _ callback: JSValue) -> Event
  func off(_ event: String)
  func reset()
}

@objc protocol EventObjectJSExport: JSExport {
  var id: String { get }
  var event: String { get }
}

final class EventBridge: NSObject, EventJSExport {
  private unowned let session: ConfigSession

  init(session: ConfigSession) {
    self.session = session
  }

  func on(_ event: String, _ callback: JSValue) -> Event {
    session.registerEvent(event, callback: callback)
  }

  func off(_ event: String) {
    session.removeEvent(event)
  }

  func reset() {
    session.resetEvents()
  }
}

extension Event: EventObjectJSExport {}
