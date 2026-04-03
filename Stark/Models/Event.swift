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
  private static let callbacks = StagedStorage<[EventType: [Event]]>(
    active: [:],
    queueLabel: "dev.tombell.stark.events",
    makeEmptyStorage: { [:] }
  )

  static func beginRecording() {
    callbacks.beginRecording()
  }

  static func commitRecording() {
    let activeListeners = callbacks.commit()?.previousActive.values.flatMap { $0 } ?? []

    for listener in activeListeners {
      removeManagedReference(for: listener)
    }
  }

  static func discardRecording() {
    let listeners = callbacks.discard()?.values.flatMap { $0 } ?? []

    for listener in listeners {
      removeManagedReference(for: listener)
    }
  }

  static func callbacks(for event: EventType) -> [Event] {
    callbacks.withActive { $0[event] ?? [] }
  }

  static func on(_ event: String, _ callback: JSValue) -> Event {
    guard let eventType = EventType(rawValue: event) else {
      log("unknown event type: \(event)", level: .error)
      return Event(event: event)
    }

    let listener = Event(event: event, callback: callback)

    callbacks.mutate { callbacks, recordingCallbacks in
      if recordingCallbacks != nil {
        var list = recordingCallbacks?[eventType] ?? []
        list.append(listener)
        recordingCallbacks?[eventType] = list
        return
      }

      var list = callbacks[eventType] ?? []
      list.append(listener)
      callbacks[eventType] = list
    }

    JSCallbackInvoker.addManagedReference(for: listener, callback: callback, owner: self)

    return listener
  }

  static func off(_ event: String) {
    guard let eventType = EventType(rawValue: event) else { return }

    let removed = callbacks.mutate { callbacks, recordingCallbacks in
      if recordingCallbacks != nil {
        return recordingCallbacks?.removeValue(forKey: eventType) ?? []
      }

      return callbacks.removeValue(forKey: eventType) ?? []
    }

    for listener in removed {
      removeManagedReference(for: listener)
    }
  }

  static func reset() {
    let all = callbacks.mutate { callbacks, recordingCallbacks in
      if recordingCallbacks != nil {
        let listeners = recordingCallbacks?.values.flatMap { $0 } ?? []
        recordingCallbacks?.removeAll()
        return listeners
      }

      let listeners = callbacks.values.flatMap { $0 }
      callbacks.removeAll()
      return listeners
    }

    for listener in all {
      removeManagedReference(for: listener)
    }
  }

  static func activeListenerCount(for event: EventType) -> Int {
    callbacks.withActive { $0[event]?.count ?? 0 }
  }

  static func recordingListenerCount(for event: EventType) -> Int {
    callbacks.withRecording { $0?[event]?.count ?? 0 }
  }

  static func resetForTesting() {
    if callbacks.withRecording({ $0 != nil }) {
      reset()
    }

    reset()
  }

  private static func removeManagedReference(for listener: Event) {
    JSCallbackInvoker.removeManagedReference(
      for: listener,
      callback: listener.callback,
      owner: self
    )
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
    JSCallbackInvoker.call(callback, withArguments: args)
  }
}
