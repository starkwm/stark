(function setup(Keymap) {
  const binds = {};

  Keymap.on = (key, modifiers, callback) => {
    const handler = new Keymap(key, modifiers, callback);

    if (handler) {
      binds[handler.id] = handler;
      return handler.id;
    }

    return null;
  };

  Keymap.off = (identifier) => {
    const handler = binds[identifier];

    if (handler) {
      handler.disable();
      delete binds[identifier];
    }
  };
})(Keymap);
