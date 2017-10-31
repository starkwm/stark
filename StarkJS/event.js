/* global Event */

(function (Event) {
  const events = {};

  Event.on = function (event, callback) {
    const handler = new Event(event, callback);

    if (handler) {
      events[handler.hashValue] = handler;
      return handler.hashValue;
    }
  };

  Event.off = function (identifier) {
    const handler = events[identifier];

    if (handler) {
      handler.disable();
      delete events[identifier];
    }
  };
})(Event);
