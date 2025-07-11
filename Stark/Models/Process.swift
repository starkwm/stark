import AppKit

private let processIgnoreList = [
  "Discord Helper (Plugin)",
  "Discord Helper (Renderer)",
  "Google Chrome Helper (Plugin)",
  "Google Chrome Helper (Renderer)",
  "Slack Helper (Plugin)",
  "Slack Helper (Renderer)",
]

class Process {
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
    self.application = NSRunningApplication(processIdentifier: self.pid)
    self.name = self.application?.localizedName ?? "-"
    self.terminated = false

    if String(info.processType) == "XPC!" {
      debug("ignoring xpc service \(self.name)")
      return nil
    }

    if processIgnoreList.contains(where: { $0 == self.name }) {
      return nil
    }
  }

  deinit {
    debug("destroying process \(self)")
  }
}

extension Process: CustomStringConvertible {
  var description: String {
    "<Process pid: \(pid), name: \(name)>"
  }
}
