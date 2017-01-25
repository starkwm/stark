/* global Bind */

(function (Bind) {
  var binds = {}

  Bind.on = function (key, modifiers, callback) {
    var handler = new Bind(key, modifiers, callback)

    if (handler) {
      binds[handler.hashValue] = handler
      return handler.hashValue
    }

    return
  }

  Bind.off = function (identifier) {
    var handler = binds[identifier]

    if (handler) {
      handler.disable()
      delete binds[identifier]
    }
  }
})(Bind)
