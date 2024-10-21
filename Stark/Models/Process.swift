import AppKit
import OSLog

private let processIgnoreList = [
  "Google Chrome Helper (Plugin)",
  "Slack Helper (Plugin)",
  "qlmanage",
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

    var pid = pid_t()
    GetProcessPID(&self.psn, &pid)

    var processName = String() as CFString
    CopyProcessName(&self.psn, &processName)

    var info = ProcessInfoRec()
    GetProcessInformation(&self.psn, &info)

    if String(info.processType) == "XPC!" {
      return nil
    }

    if processIgnoreList.contains(where: { $0 == processName as String }) {
      return nil
    }

    self.pid = pid
    self.name = processName as String
    self.terminated = false
    self.application = NSRunningApplication(processIdentifier: self.pid)
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
