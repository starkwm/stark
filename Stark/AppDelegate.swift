import Cocoa
//import Sentry

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var config: Config
    var context: Context

    var aboutWindowController = AboutWindowController(windowNibName: NSNib.Name(rawValue: "AboutWindow"))

    override init() {
        config = Config()
        context = Context(config: config)
    }

    func applicationDidFinishLaunching(_: Notification) {
//        SentryClient.shared = SentryClient(dsnString: starkSentryDSN)
//        SentryClient.shared?.startCrashHandler()

        AccessibilityHelper.askForAccessibilityIfNeeded()

        setupStatusItem()

        context.setup()

        NotificationCenter.default
            .post(name: Notification.Name(rawValue: starkStartNotification), object: self)
    }

    func setupStatusItem() {
        let image = NSImage(named: NSImage.Name(rawValue: "StatusItemIcon"))
        image?.isTemplate = true

        statusItem.highlightMode = true
        statusItem.image = image

        let loginMenuItem = NSMenuItem(title: "Run at login", action: #selector(AppDelegate.toggleRunAtLogin), keyEquivalent: "")

        let menu = NSMenu()
        menu.addItem(withTitle: "About", action: #selector(AppDelegate.about), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Reload config file", action: #selector(AppDelegate.reloadConfig), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(loginMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Stark", action: #selector(AppDelegate.quit), keyEquivalent: "")

        loginMenuItem.state = LaunchAgentHelper.enabled() ? NSControl.StateValue.onState : NSControl.StateValue.offState

        statusItem.menu = menu
    }

    @objc
    func about(sender _: AnyObject?) {
        NSApp.activate(ignoringOtherApps: true)
        aboutWindowController.showWindow(nil)
    }

    @objc
    func reloadConfig(sender _: AnyObject?) {
        context.setup()
    }

    @objc
    func toggleRunAtLogin(sender: NSMenuItem) {
        if sender.state == NSControl.StateValue.onState {
            LaunchAgentHelper.remove()
            sender.state = NSControl.StateValue.offState
        } else {
            _ = LaunchAgentHelper.add()
            sender.state = NSControl.StateValue.onState
        }
    }

    @objc
    func quit(sender _: AnyObject?) {
        NSApp.terminate(nil)
    }
}
