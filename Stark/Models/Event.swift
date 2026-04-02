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
  private static var recordingCallbacks: [EventType: [Event]]?
  private static let queue = DispatchQueue(label: "dev.tombell.stark.events")

  static func beginRecording() {
    queue.sync {
      recordingCallbacks = [:]
    }
  }

  static func commitRecording() {
    let activeListeners: [Event] = queue.sync {
      guard let recordingCallbacks else { return [] }

      let activeListeners = callbacks.values.flatMap { $0 }
      callbacks = recordingCallbacks
      self.recordingCallbacks = nil

      return activeListeners
    }

    for listener in activeListeners {
      removeManagedReference(for: listener)
    }
  }

  static func discardRecording() {
    let listeners: [Event] = queue.sync {
      let listeners = recordingCallbacks?.values.flatMap { $0 } ?? []
      recordingCallbacks = nil
      return listeners
    }

    for listener in listeners {
      removeManagedReference(for: listener)
    }
  }

  static func callbacks(for event: EventType) -> [Event] {
    queue.sync { callbacks[event] ?? [] }
  }

  static func on(_ event: String, _ callback: JSValue) -> Event {
    guard let eventType = EventType(rawValue: event) else {
      log("unknown event type: \(event)", level: .error)
      return Event(event: event)
    }

    let listener = Event(event: event, callback: callback)

    if recordingCallbacks != nil {
      queue.sync {
        var list = recordingCallbacks?[eventType] ?? []
        list.append(listener)
        recordingCallbacks?[eventType] = list
      }

      callback.context.virtualMachine.addManagedReference(listener, withOwner: self)
      return listener
    }

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

    if recordingCallbacks != nil {
      let removed: [Event] = queue.sync {
        let list = recordingCallbacks?.removeValue(forKey: eventType) ?? []
        return list
      }

      for listener in removed {
        removeManagedReference(for: listener)
      }

      return
    }

    let removed: [Event] = queue.sync {
      let list = callbacks.removeValue(forKey: eventType) ?? []
      return list
    }

    for listener in removed {
      removeManagedReference(for: listener)
    }
  }

  static func reset() {
    if recordingCallbacks != nil {
      let all: [Event] = queue.sync {
        let list = recordingCallbacks?.values.flatMap { $0 } ?? []
        recordingCallbacks?.removeAll()
        return list
      }

      for listener in all {
        removeManagedReference(for: listener)
      }

      return
    }

    let all: [Event] = queue.sync {
      let list = callbacks.values.flatMap { $0 }
      callbacks.removeAll()
      return list
    }

    for listener in all {
      removeManagedReference(for: listener)
    }
  }

  static func activeListenerCount(for event: EventType) -> Int {
    queue.sync { callbacks[event]?.count ?? 0 }
  }

  static func recordingListenerCount(for event: EventType) -> Int {
    queue.sync { recordingCallbacks?[event]?.count ?? 0 }
  }

  static func resetForTesting() {
    if recordingCallbacks != nil {
      reset()
    }

    reset()
  }

  private static func removeManagedReference(for listener: Event) {
    guard let callback = listener.callback?.value else { return }

    callback.context.virtualMachine.removeManagedReference(listener, withOwner: self)
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
