import AppKit

open class AboutWindowController: NSWindowController {
    fileprivate var appVersion: String = ""

    @IBOutlet var versionLabel: NSTextField!

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override open func windowDidLoad() {
        super.windowDidLoad()

        window?.backgroundColor = NSColor.white

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

    fileprivate func valueFromInfoDict(_ key: String) -> String {
        let dict = Bundle.main.infoDictionary!

        if let value = dict[key] as? String {
            return value
        }

        return ""
    }
}
