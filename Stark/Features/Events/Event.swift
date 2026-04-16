import JavaScriptCore

class Event: NSObject {
  var id: String
  var event: String

  override var description: String {
    "<Event id: \(id), event: \(event)>"
  }

  private var callback: JSValue?

  init(event: String) {
    self.event = event
    self.id = UUID().uuidString
  }

  init(event: String, callback: JSValue) {
    self.event = event
    self.id = UUID().uuidString
    self.callback = callback

    super.init()
  }

  deinit {
    log("event deinit \(self)")
  }

  func call(withArguments args: [Any]) {
    JSCallbackInvoker.call(callback, withArguments: args)
  }
}
