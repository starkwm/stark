/* global Timer */

(function (Timer) {
  const timers = {};

  Timer.after = (interval, callback) => {
    const timer = new Timer(interval, false, handler => {
      callback(handler);
      Timer.off(handler.hashValue);
    });

    timers[timer.hashValue] = timer;
    return timer.hashValue;
  };

  Timer.every = (interval, callback) => {
    const timer = new Timer(interval, true, callback);
    timers[timer.hashValue] = timer;
    return timer.hashValue;
  };

  Timer.off = identifier => {
    const timer = timers[identifier];

    if (timer) {
      timer.stop();
      delete timers[identifier];
    }
  };
})(Timer);

this.clearTimeout = Timer.off;
this.clearInterval = Timer.off;

this.setTimeout = (callback, ms) => {
  return Timer.after(ms / 1000, callback);
};

this.setInterval = (callback, ms) => {
  return Timer.every(ms / 1000, callback);
};
