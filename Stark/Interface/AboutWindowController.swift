import AppKit

public class AboutWindowController: NSWindowController {
    private var appVersion: String = ""

    @IBOutlet var versionLabel: NSTextField!

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override public func windowDidLoad() {
        super.windowDidLoad()

        window?.backgroundColor = NSColor.whiteColor()

        if appVersion.characters.count <= 0 {
            let version = valueFromInfoDict("CFBundleVersion")
            let shortVersion = valueFromInfoDict("CFBundleShortVersionString")

            appVersion = "v\(shortVersion) build \(version)"

            let buildName = valueFromInfoDict("StarkBuildVersion")

            if buildName.characters.count > 0 {
                appVersion += " (\(buildName))"
            }

            versionLabel.stringValue = appVersion
        }
    }

    private func valueFromInfoDict(key: String) -> String {
        let dict = NSBundle.mainBundle().infoDictionary!

        if let value = dict[key] as? String {
            return value
        }

        return ""
    }
}
