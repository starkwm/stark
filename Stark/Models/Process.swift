import AppKit

private let processIgnoreList = [
  "Discord Helper (Plugin)",
  "Discord Helper (Renderer)",
  "Google Chrome Helper (Plugin)",
  "Google Chrome Helper (Renderer)",
  "Slack Helper (Plugin)",
  "Slack Helper (Renderer)",
]

class Process: CustomStringConvertible {
  var description: String {
    "<Process pid: \(pid), name: \(name)>"
  }

  var psn: ProcessSerialNumber
  var pid: pid_t
  var name: String
  var terminated: Bool
  var application: NSRunningApplication?

  var policy: NSApplication.ActivationPolicy?

  init?(psn: ProcessSerialNumber) {
    self.psn = psn

    var info = ProcessInfoRec()
    GetProcessInformation(&self.psn, &info)

    var pid = pid_t()
    GetProcessPID(&self.psn, &pid)

    self.pid = pid
    application = NSRunningApplication(processIdentifier: self.pid)
    name = application?.localizedName ?? "-"
    terminated = false

    if NSFileTypeForHFSTypeCode(info.processType).trimmingCharacters(in: CharacterSet(charactersIn: "'")) == "XPC!" {
      log("ignoring xpc service \(name)")
      return nil
    }

    if processIgnoreList.contains(where: { $0 == name }) {
      return nil
    }
  }

  deinit {
    log("process deinit \(self)")
  }
}
