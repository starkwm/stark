/* global Bind */

(function (Bind) {
  let binds = {};

  Bind.on = (key, modifiers, callback) => {
    const handler = new Bind(key, modifiers, callback);

    if (handler) {
      binds[handler.hashValue] = handler;
      return handler.hashValue;
    }

    return;
  }

  Bind.off = (identifier) => {
    const handler = binds[identifier];

    if (handler) {
      handler.disable();
      delete binds[identifier];
    }
  }
})(Bind);
