(function(Timer) {

  var timers = {};

  Timer.after = function(interval, callback) {
    var timer = new Timer(interval, false, function(handler) {
      callback(handler);
      Timer.off(handler.hashValue);
    });

    timers[timer.hashValue] = timer;
    return timer.hashValue;
  }

  Timer.every = function(interval, callbac) {
    var timer = new Timer(interval, true, callbac);
    timers[timer.hashValue] = timer;
    return timer.hashValue;
  }

  Timer.off = function(identifier) {
    var timer = timers[identifier];

    if (timer) {
      timer.stop();
      delete timers[identifier];
    }
  }

}(Timer);

this.clearTimeout = Timer.off;
this.clearInterval = Timer.off;

this.setTimeout = function(callback, ms) {
  return Timer.after(ms / 1000, callback);
}

this.setInterval = function(callback, ms) {
  return Timer.every(ms / 1000, callback);
}
