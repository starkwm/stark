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
    ?? (primaryPaths.first! as NSString).resolvingSymlinksInPath
}

class ConfigManager {
  static var shared = ConfigManager()

  private var path: String = resolvePrimaryPath()
  private var fileSystemSource: DispatchSourceFileSystemObject?

  private var context: JSContext?

  func start() -> Bool {
    guard load() else { return false }
    guard setupFileMonitor() else { return false }

    return true
  }

  func stop() {
    fileSystemSource?.cancel()
    fileSystemSource = nil

    ShortcutManager.stop()
  }

  private func load() -> Bool {
    Keymap.reset()

    ShortcutManager.stop()
    ShortcutManager.reset()

    guard setupAPI() else { return false }
    guard executeConfig() else { return false }

    ShortcutManager.start()

    return true
  }

  private func setupAPI() -> Bool {
    context = nil
    context = JSContext(virtualMachine: JSVirtualMachine())

    guard let context = context else {
      log("could not create javascript context", level: .error)
      return false
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

    return true
  }

  private func executeConfig() -> Bool {
    if !FileManager.default.fileExists(atPath: path) {
      log("configuration file does not exist \(path)", level: .error)
      return false
    }

    guard let context else {
      log("javascript context is not defined", level: .error)
      return false
    }

    guard let scriptContents = try? String(contentsOfFile: path, encoding: .utf8) else {
      log("could not read file \(path)", level: .error)
      return false
    }

    context.evaluateScript(scriptContents)

    return true
  }

  private func setupFileMonitor() -> Bool {
    let file = NSURL.fileURL(withPath: path)
    let fd = open(file.path, O_EVTONLY)

    fileSystemSource = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd,
      eventMask: .write,
      queue: DispatchQueue(label: "dev.tombell.stark.config")
    )

    guard let fileSystemSource = fileSystemSource else {
      log("could not setup file monitoring", level: .error)
      return false
    }

    fileSystemSource.setEventHandler {
      log("config file changed, reloading...", level: .info)

      if !self.load() {
        log("could not reload config file", level: .error)
      }
    }

    fileSystemSource.setCancelHandler {
      close(fd)
    }

    fileSystemSource.resume()

    return true
  }
}
