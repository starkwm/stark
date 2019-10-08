/* global Event */

(function setup(Event) {
  const events = {};

  // eslint-disable-next-line no-param-reassign
  Event.on = (event, callback) => {
    const handler = new Event(event, callback);

    if (handler) {
      events[handler.id] = handler;
      return handler.id;
    }

    return null;
  };

  // eslint-disable-next-line no-param-reassign
  Event.off = (identifier) => {
    const handler = events[identifier];

    if (handler) {
      handler.disable();
      delete events[identifier];
    }
  };
}(Event));
