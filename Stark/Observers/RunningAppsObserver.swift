import AppKit

private let NSWorkspaceRunningApplicationsKeyPath = "runningApplications"

class RunningAppsObserver: NSObject {
    var observers = [pid_t: AppObserver]()

    override init() {
        super.init()

        NSWorkspace
            .shared
            .addObserver(self, forKeyPath: NSWorkspaceRunningApplicationsKeyPath, options: [.old, .new], context: nil)

        observe(applications: NSWorkspace.shared.runningApplications)
    }

    deinit {
        NSWorkspace
            .shared
            .removeObserver(self, forKeyPath: NSWorkspaceRunningApplicationsKeyPath)
    }

    override func observeValue(forKeyPath keyPath: String?, of _: Any?, change: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        if keyPath != NSWorkspaceRunningApplicationsKeyPath {
            return
        }

        guard let change = change else {
            return
        }

        var apps: [NSRunningApplication]?

        if let rv = change[NSKeyValueChangeKey.kindKey] as? UInt, let kind = NSKeyValueChange(rawValue: rv) {
            switch kind {
            case .insertion:
                apps = change[NSKeyValueChangeKey.newKey] as? [NSRunningApplication]
                observe(applications: apps ?? [])
            case .removal:
                apps = change[NSKeyValueChangeKey.oldKey] as? [NSRunningApplication]
                unobserve(applications: apps ?? [])
            default:
                return
            }
        }
    }

    private func observe(applications: [NSRunningApplication]) {
        for app in applications {
            observers[app.processIdentifier] = AppObserver(app: app)
        }
    }

    private func unobserve(applications: [NSRunningApplication]) {
        for app in applications {
            observers.removeValue(forKey: app.processIdentifier)
        }
    }
}
