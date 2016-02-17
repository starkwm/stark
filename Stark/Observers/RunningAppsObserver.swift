import AppKit

private let NSWorkspaceRunningApplicationsKeyPath = "runningApplications";

public class RunningAppsObserver: NSObject {
    public var observers = [pid_t: AppObserver]()

    override init() {
        super.init()

        NSWorkspace
            .sharedWorkspace()
            .addObserver(self, forKeyPath: NSWorkspaceRunningApplicationsKeyPath, options: [.Old, .New], context: nil)

        observeApplications(NSWorkspace.sharedWorkspace().runningApplications)
    }

    deinit {
        NSWorkspace
            .sharedWorkspace()
            .removeObserver(self, forKeyPath: NSWorkspaceRunningApplicationsKeyPath)
    }

    private func observeApplications(apps: [NSRunningApplication]) {
        for app in apps {
            observers[app.processIdentifier] = AppObserver(app: app)
        }
    }

    private func removeApplications(apps: [NSRunningApplication]) {
        for app in apps {
            observers.removeValueForKey(app.processIdentifier)
        }
    }

    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String: AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath != NSWorkspaceRunningApplicationsKeyPath {
            return
        }

        guard let change = change else {
            return
        }

        var apps: [NSRunningApplication]? = nil

        if let rv = change[NSKeyValueChangeKindKey] as? UInt, kind = NSKeyValueChange(rawValue: rv) {

            switch kind {
            case .Insertion:
                apps = change[NSKeyValueChangeNewKey] as? [NSRunningApplication]
            case .Removal:
                apps = change[NSKeyValueChangeOldKey] as? [NSRunningApplication]
            default:
                return
            }
        }

        print(apps)
    }
}