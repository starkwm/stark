import JavaScriptCore

class Event: NSObject {
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
