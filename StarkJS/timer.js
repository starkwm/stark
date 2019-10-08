/* global Timer */

(function setup(Timer) {
  const timers = {};

  // eslint-disable-next-line no-param-reassign
  Timer.after = (interval, callback) => {
    const timer = new Timer(interval, false, (handler) => {
      callback(handler);
      Timer.off(handler.id);
    });

    timers[timer.id] = timer;
    return timer.id;
  };

  // eslint-disable-next-line no-param-reassign
  Timer.every = (interval, callback) => {
    const timer = new Timer(interval, true, callback);
    timers[timer.id] = timer;
    return timer.id;
  };

  // eslint-disable-next-line no-param-reassign
  Timer.off = (identifier) => {
    const timer = timers[identifier];

    if (timer) {
      timer.stop();
      delete timers[identifier];
    }
  };
}(Timer));

this.clearTimeout = Timer.off;
this.clearInterval = Timer.off;

this.setTimeout = (callback, ms) => Timer.after(ms / 1000, callback);
this.setInterval = (callback, ms) => Timer.every(ms / 1000, callback);
