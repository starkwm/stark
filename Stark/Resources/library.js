(function setup(Bind) {
  const binds = {};

  Bind.on = (key, modifiers, callback) => {
    const handler = new Bind(key, modifiers, callback);

    if (handler) {
      binds[handler.id] = handler;
      return handler.id;
    }

    return null;
  };

  Bind.off = (identifier) => {
    const handler = binds[identifier];

    if (handler) {
      handler.disable();
      delete binds[identifier];
    }
  };
}(Bind));

(function setup(Task) {
  const tasks = {};

  Task.run = (path, args, callback) => {
    const task = new Task(path, args, (handler) => {
      if (callback) {
        callback(handler);
      }

      Task.terminate(handler.id);
    });

    if (task) {
      tasks[task.id] = task;
      return task.id;
    }

    return null;
  };

  Task.terminate = (identifier) => {
    const task = tasks[identifier];

    if (task) {
      task.terminate();
      delete tasks[identifier];
    }
  };
}(Task));

(function setup(Timer) {
  const timers = {};

  Timer.after = (interval, callback) => {
    const timer = new Timer(interval, false, (handler) => {
      callback(handler);
      Timer.off(handler.id);
    });

    timers[timer.id] = timer;
    return timer.id;
  };

  Timer.every = (interval, callback) => {
    const timer = new Timer(interval, true, callback);
    timers[timer.id] = timer;
    return timer.id;
  };

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
