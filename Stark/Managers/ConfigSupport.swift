import AppKit
import JavaScriptCore

struct ConfigPathResolver {
  var resolvePrimaryPath: (_ paths: [String], _ fileSystem: ConfigFileSystem) -> String

  static let live = ConfigPathResolver(
    resolvePrimaryPath: { paths, fileSystem in
      paths
        .lazy
        .map { ($0 as NSString).resolvingSymlinksInPath }
        .first { fileSystem.fileExists($0) }
        ?? (paths[0] as NSString).resolvingSymlinksInPath
    }
  )
}

struct JSBridgeInstaller {
  var install: (JSContext) -> Void

  static let live = JSBridgeInstaller(
    install: { context in
      context.exceptionHandler = { _, err in
        log("javascript exception - \(String(describing: err))", level: .error)
      }

      let print: @convention(block) (String) -> Void = { message in
        log(message, level: .info)
      }

      context.setObject(print, forKeyedSubscript: "print" as NSString)
      context.setObject(Keymap.self, forKeyedSubscript: "Keymap" as NSString)
      context.setObject(Event.self, forKeyedSubscript: "Event" as NSString)
      context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as NSString)
      context.setObject(Space.self, forKeyedSubscript: "Space" as NSString)
      context.setObject(Application.self, forKeyedSubscript: "Application" as NSString)
      context.setObject(Window.self, forKeyedSubscript: "Window" as NSString)
    }
  )
}

struct ScriptRuntimeFactory {
  var createContext: () -> Result<JSContext, JSExceptionError>

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

struct ConfigScriptExecutor {
  var executeScript: (JSContext, String) -> Result<Void, Error>

  static let live = ConfigScriptExecutor(
    executeScript: { context, script in
      context.evaluateScript(script)

      if let exception = context.exception {
        return .failure(JSExceptionError.exception("JS exception: \(exception)"))
      }

      return .success(())
    }
  )
}

struct ConfigFileWatcher {
  var startMonitoring: (
    _ path: String,
    _ queue: DispatchQueue,
    _ reloadHandler: @escaping (_ needsMonitorRestart: Bool) -> Void
  ) -> Result<DispatchSourceFileSystemObject, FileError>

  static let live = ConfigFileWatcher(
    startMonitoring: { path, queue, reloadHandler in
      let file = NSURL.fileURL(withPath: path)
      let fd = open(file.path, O_EVTONLY)

      guard fd >= 0 else {
        return .failure(.monitorFailed("could not open config file for monitoring"))
      }

      let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd,
        eventMask: [.write, .delete, .rename],
        queue: queue
      )

      source.setEventHandler { [weak source] in
        guard let source else { return }

        let events = source.data
        let needsMonitorRestart = events.contains(.delete) || events.contains(.rename)
        let needsReload = needsMonitorRestart || events.contains(.write)

        if needsReload {
          reloadHandler(needsMonitorRestart)
        }
      }

      source.setCancelHandler {
        close(fd)
      }

      source.resume()

      return .success(source)
    }
  )
}
