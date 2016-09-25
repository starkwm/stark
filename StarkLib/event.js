(function(Event) {

  var events = {};

  Event.on = function(event, callback) {
    var handler = new Event(event, callback);

    if (handler) {
      events[handler.hashValue] = handler;
      return handler.hashValue;
    }

    return;
  }

  Event.off = function(identifier) {
    var handler = events[identifier];

    if (handler) {
      handler.disable();
      delete events[identifier];
    }
  }

})(Event);
