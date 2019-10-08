/* global Bind */

(function setup(Bind) {
  const binds = {};

  // eslint-disable-next-line no-param-reassign
  Bind.on = (key, modifiers, callback) => {
    const handler = new Bind(key, modifiers, callback);

    if (handler) {
      binds[handler.id] = handler;
      return handler.id;
    }

    return null;
  };

  // eslint-disable-next-line no-param-reassign
  Bind.off = (identifier) => {
    const handler = binds[identifier];

    if (handler) {
      handler.disable();
      delete binds[identifier];
    }
  };
}(Bind));
