/* global Task */

(function setup(Task) {
  const tasks = {};

  // eslint-disable-next-line no-param-reassign
  Task.run = (path, args, callback) => {
    const handler = new Task(path, args, callback);

    if (handler) {
      tasks[handler.id] = handler;
      return handler.id;
    }

    return null;
  };
}(Task));
