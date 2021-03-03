import AppKit

class RunningAppsObserver {
    var observer: NSKeyValueObservation?

    var observers = [pid_t: AppObserver]()

    init() {
        observer = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new]) { _, change in
            switch change.kind {
            case .insertion:
                let apps = change.newValue as [NSRunningApplication]?
                self.observe(applications: apps ?? [])
            case .removal:
                let apps = change.oldValue as [NSRunningApplication]?
                self.unobserve(applications: apps ?? [])
            default:
                return
            }
        }

        observe(applications: NSWorkspace.shared.runningApplications)
    }

    private func observe(applications: [NSRunningApplication]) {
        applications.forEach { observers[$0.processIdentifier] = AppObserver(app: $0) }
    }

    private func unobserve(applications: [NSRunningApplication]) {
        applications.forEach { observers.removeValue(forKey: $0.processIdentifier) }
    }
}
