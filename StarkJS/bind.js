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
