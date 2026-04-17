struct RuntimeEventDispatcher {
  let listenerProvider: EventListenerProviding

  func emit(_ type: EventType, payload: Any, message: String, level: LogLevel = .info) {
    log(message, level: level)

    for listener in listenerProvider.callbacks(for: type) {
      listener.call(withArguments: [payload])
    }
  }
}
