(function setup(Event) {
  const events = {};

  Event.on = (event, callback) => {
    const handler = new Event(event, callback);

    if (handler) {
      events[handler.id] = handler;
      return handler.id;
    }

    return null;
  };

  Event.off = (identifier) => {
    const handler = events[identifier];

    if (handler) {
      handler.disable();
      delete events[identifier];
    }
  };
}(Event));
