import AppKit

private let NSWorkspaceRunningApplicationsKeyPath = "runningApplications"

open class RunningAppsObserver: NSObject {
    open var observers = [pid_t: AppObserver]()

    override init() {
        super.init()

        NSWorkspace
            .shared()
            .addObserver(self, forKeyPath: NSWorkspaceRunningApplicationsKeyPath, options: [.old, .new], context: nil)

        observeApplications(NSWorkspace.shared().runningApplications)
    }

    deinit {
        NSWorkspace
            .shared()
            .removeObserver(self, forKeyPath: NSWorkspaceRunningApplicationsKeyPath)
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath != NSWorkspaceRunningApplicationsKeyPath {
            return
        }

        guard let change = change else {
            return
        }

        var apps: [NSRunningApplication]? = nil

        if let rv = change[NSKeyValueChangeKey.kindKey] as? UInt, let kind = NSKeyValueChange(rawValue: rv) {
            switch kind {
            case .insertion:
                apps = change[NSKeyValueChangeKey.newKey] as? [NSRunningApplication]
                observeApplications(apps ?? [])
            case .removal:
                apps = change[NSKeyValueChangeKey.oldKey] as? [NSRunningApplication]
                removeApplications(apps ?? [])
            default:
                return
            }
        }
    }

    fileprivate func observeApplications(_ apps: [NSRunningApplication]) {
        for app in apps {
            observers[app.processIdentifier] = AppObserver(app: app)
        }
    }

    fileprivate func removeApplications(_ apps: [NSRunningApplication]) {
        for app in apps {
            observers.removeValue(forKey: app.processIdentifier)
        }
    }
}
