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

class Event: NSObject, EventObjectJSExport {
  var id: String
  var event: String

  override var description: String {
    "<Event id: \(id), event: \(event)>"
  }

  private var callback: JSManagedValue?

  init(event: String) {
    self.event = event
    self.id = UUID().uuidString
  }

  init(event: String, callback: JSValue, callbackOwner: AnyObject) {
    self.event = event
    self.id = UUID().uuidString
    self.callback = JSManagedValue(value: callback, andOwner: callbackOwner)

    super.init()

    JSCallbackInvoker.addManagedReference(for: self, callback: callback, owner: callbackOwner)
  }

  deinit {
    log("event deinit \(self)")
  }

  func call(withArguments args: [Any]) {
    JSCallbackInvoker.call(callback, withArguments: args)
  }

  func detachCallback(from owner: AnyObject) {
    JSCallbackInvoker.removeManagedReference(for: self, callback: callback, owner: owner)
  }
}
