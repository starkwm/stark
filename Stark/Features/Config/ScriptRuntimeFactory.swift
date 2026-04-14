import JavaScriptCore

struct ScriptRuntimeFactory {
  static func live(bridgeInstaller: JSBridgeInstaller = .live) -> ScriptRuntimeFactory {
    ScriptRuntimeFactory(
      createContext: { session in
        let context = JSContext(virtualMachine: JSVirtualMachine())

        guard let context else {
          throw JSExceptionError.exception("Could not create javascript context")
        }

        session.attach(context: context)
        bridgeInstaller.install(context, session)

        return context
      }
    )
  }

  var createContext: (ConfigSession) throws -> JSContext
}
