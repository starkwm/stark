import AppKit
import JavaScriptCore

private let primaryPaths: [String] = [
  "~/.stark.js",
  "~/.config/stark/stark.js",
  "~/Library/Application Support/Stark/stark.js",
]

private func resolvePrimaryPath() -> String {
  return primaryPaths
    .lazy
    .map { ($0 as NSString).resolvingSymlinksInPath }
    .first { FileManager.default.fileExists(atPath: $0) }
    ?? (primaryPaths[0] as NSString).resolvingSymlinksInPath
}

final class ConfigManager {
  static var shared = ConfigManager()

  private var path: String = resolvePrimaryPath()
  private var fileSystemSource: DispatchSourceFileSystemObject?

  private var context: JSContext?

  func start() -> Result<Void, Error> {
    switch load() {
    case .success:
      break
    case .failure(let error):
      return .failure(error)
    }

    switch setupFileMonitor() {
    case .success:
      return .success(())
    case .failure(let error):
      return .failure(error)
    }
  }

  func stop() {
    fileSystemSource?.cancel()
    fileSystemSource = nil

    ShortcutManager.stop()
  }

  private func load() -> Result<Void, Error> {
    Keymap.reset()

    ShortcutManager.stop()
    ShortcutManager.reset()

    switch setupAPI() {
    case .success:
      break
    case .failure(let error):
      return .failure(error)
    }

    switch executeConfig() {
    case .success:
      ShortcutManager.start()
      return .success(())
    case .failure(let error):
      return .failure(error)
    }
  }

  private func setupAPI() -> Result<Void, JSExceptionError> {
    context = nil
    context = JSContext(virtualMachine: JSVirtualMachine())

    guard let context = context else {
      return .failure(.exception("Could not create javascript context"))
    }

    context.exceptionHandler = { _, err in
      log("javascript exception - \(String(describing: err))", level: .error)
    }

    let print: @convention(block) (String) -> Void = { message in
      log(message, level: .info)
    }
    context.setObject(print, forKeyedSubscript: "print" as NSString)
    context.setObject(Keymap.self, forKeyedSubscript: "Keymap" as NSString)
    context.setObject(NSScreen.self, forKeyedSubscript: "Screen" as NSString)
    context.setObject(Space.self, forKeyedSubscript: "Space" as NSString)
    context.setObject(Application.self, forKeyedSubscript: "Application" as NSString)
    context.setObject(Window.self, forKeyedSubscript: "Window" as NSString)

    return .success(())
  }

  private func executeConfig() -> Result<Void, Error> {
    if !FileManager.default.fileExists(atPath: path) {
      return .failure(FileError.notFound(path))
    }

    guard let context else {
      return .failure(StateError.invalidState("javascript context is not defined"))
    }

    guard let scriptContents = try? String(contentsOfFile: path, encoding: .utf8) else {
      return .failure(FileError.readFailed("could not read file \(path)"))
    }

    context.evaluateScript(scriptContents)

    if let exception = context.exception {
      return .failure(JSExceptionError.exception("JS exception: \(exception)"))
    }

    return .success(())
  }

  private func setupFileMonitor() -> Result<Void, FileError> {
    let file = NSURL.fileURL(withPath: path)
    let fd = open(file.path, O_EVTONLY)

    guard fd >= 0 else {
      return .failure(.monitorFailed("could not open config file for monitoring"))
    }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd,
      eventMask: .write,
      queue: DispatchQueue(label: "dev.tombell.stark.config")
    )

    fileSystemSource = source

    source.setEventHandler {
      log("config file changed, reloading...", level: .info)

      switch self.load() {
      case .success: break
      case .failure(let error):
        log("could not reload config file: \(error)", level: .error)
      }
    }

    source.setCancelHandler {
      close(fd)
    }

    source.resume()

    return .success(())
  }
}
