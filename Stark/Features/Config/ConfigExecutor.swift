import JavaScriptCore

struct ConfigExecutor {
  var createContext: () -> Result<JSContext, JSExceptionError>
  var executeScript: (JSContext, String) -> Result<Void, Error>
}
