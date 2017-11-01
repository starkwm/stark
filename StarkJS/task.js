/* global Task */
(function (Task) {
  const tasks = {};

  Task.run = (path, args, callback) => {
    const task = new Task(path, args, handler => {
      callback(handler);
      Task.terminate(handler.hashValue);
    });

    tasks[task.hashValue] = task;
    return task.hashValue;
  };

  Task.terminate = identifier => {
    const task = tasks[identifier];

    if (task) {
      task.terminate();
      delete tasks[identifier];
    }
  };
})(Task);
