import JavaScriptCore

struct ConfigExecutor {
  var createContext: (ConfigSession) throws -> JSContext
  var executeScript: (ConfigSession, JSContext, String) throws -> Void
}
