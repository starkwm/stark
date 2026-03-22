import JavaScriptCore

/// Protocol exposing event callback functionality to JavaScript.
/// Allows registering JavaScript callbacks for system events like window and application lifecycle changes.
@objc protocol EventJSExport: JSExport {
  // MARK: - Event Management

  /// Registers a callback for the specified event type.
  /// - Parameters:
  ///   - event: The event name (e.g., "windowFocused", "applicationLaunched")
  ///   - callback: JavaScript function to execute when the event fires
  /// - Returns: The created event listener instance
  static func on(_ event: String, _ callback: JSValue) -> Event

  /// Unregisters all listeners for the specified event type.
  /// - Parameter event: The event name to unregister listeners for
  static func off(_ event: String)

  /// Unregisters all event listeners across all event types.
  static func reset()

  // MARK: - Properties

  /// Unique identifier for this event listener.
  var id: String { get }

  /// The event name this listener is registered for.
  var event: String { get }
}

class Event: NSObject, EventJSExport {
  private static var callbacks: [EventType: [Event]] = [:]
  private static let queue = DispatchQueue(label: "dev.tombell.stark.events")

  static func callbacks(for event: EventType) -> [Event] {
    queue.sync { callbacks[event] ?? [] }
  }

  static func on(_ event: String, _ callback: JSValue) -> Event {
    guard let eventType = EventType(rawValue: event) else {
      log("unknown event type: \(event)", level: .error)
      return Event(event: event)
    }

    let listener = Event(event: event, callback: callback)

    queue.sync {
      var list = callbacks[eventType] ?? []
      list.append(listener)
      callbacks[eventType] = list
    }

    callback.context.virtualMachine.addManagedReference(listener, withOwner: self)

    return listener
  }

  static func off(_ event: String) {
    guard let eventType = EventType(rawValue: event) else { return }

    let removed: [Event] = queue.sync {
      let list = callbacks.removeValue(forKey: eventType) ?? []
      return list
    }

    for listener in removed {
      listener.callback?.value?.context.virtualMachine.removeManagedReference(
        listener,
        withOwner: self
      )
    }
  }

  static func reset() {
    let all: [Event] = queue.sync {
      let list = callbacks.values.flatMap { $0 }
      callbacks.removeAll()
      return list
    }

    for listener in all {
      listener.callback?.value?.context.virtualMachine.removeManagedReference(
        listener,
        withOwner: self
      )
    }
  }

  var id: String
  var event: String

  private var callback: JSManagedValue?

  override var description: String {
    "<Event id: \(id), event: \(event)>"
  }

  init(event: String) {
    self.event = event
    self.id = UUID().uuidString
  }

  init(event: String, callback: JSValue) {
    self.event = event
    self.id = UUID().uuidString

    super.init()

    self.callback = JSManagedValue(value: callback, andOwner: self)
  }

  deinit {
    log("event deinit \(self)")
  }

  func call(withArguments args: [Any]) {
    guard let callback = callback?.value else { return }

    guard let context = JSContext(virtualMachine: callback.context.virtualMachine) else { return }

    context.exceptionHandler = { _, err in
      log("unhandled javascript exception - \(String(describing: err))", level: .error)
    }

    let function = JSValue(object: callback, in: context)
    function?.call(withArguments: args)
  }
}
