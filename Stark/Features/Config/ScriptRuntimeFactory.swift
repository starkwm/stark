import JavaScriptCore

struct ScriptRuntimeFactory {
  var createContext: () -> Result<JSContext, JSExceptionError>

  /// Creates a JS context factory preloaded with Stark's bridge objects.
  static func live(bridgeInstaller: JSBridgeInstaller = .live) -> ScriptRuntimeFactory {
    ScriptRuntimeFactory(
      createContext: {
        let context = JSContext(virtualMachine: JSVirtualMachine())

        guard let context else {
          return .failure(.exception("Could not create javascript context"))
        }

        bridgeInstaller.install(context)

        return .success(context)
      }
    )
  }
}
