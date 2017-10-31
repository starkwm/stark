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

        if appVersion.isEmpty {
            let build = valueFromInfoDict("CFBundleVersion")
            let version = valueFromInfoDict("CFBundleShortVersionString")

            versionLabel.stringValue = "Version \(version) (\(build))"
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
