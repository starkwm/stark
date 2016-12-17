import AppKit

open class AboutWindowController: NSWindowController {
    fileprivate var appVersion: String = ""

    @IBOutlet fileprivate var versionLabel: NSTextField!

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open override func windowDidLoad() {
        super.windowDidLoad()

        window?.backgroundColor = NSColor.white

        if appVersion.characters.isEmpty {
            let version = valueFromInfoDict("CFBundleVersion")
            let shortVersion = valueFromInfoDict("CFBundleShortVersionString")

            appVersion = "v\(shortVersion) build \(version)"
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
