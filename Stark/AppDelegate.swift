import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)

    var config: Config
    var context: Context

    var aboutWindowController = AboutWindowController(windowNibName: "AboutWindow")

    override init() {
        config = Config()
        context = Context(config: config)
    }

    func applicationDidFinishLaunching(aNotification: Notification) {
        AccessibilityHelper.askForAccessibilityIfNeeded()

        setupStatusItem()

        context.setup()

        NotificationCenter.default
            .post(name: Notification.Name(rawValue: starkStartNotification), object: self)
    }

    func setupStatusItem() {
        let image = NSImage(named: "StatusItemIcon")
        image?.isTemplate = true

        statusItem.highlightMode = true
        statusItem.image = image

        let loginMenuItem = NSMenuItem(title: "Run at login", action: #selector(AppDelegate.toggleRunAtLogin), keyEquivalent: "")

        let menu = NSMenu()
        menu.addItem(withTitle: "About", action: #selector(AppDelegate.about), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Edit config file", action: #selector(AppDelegate.editConfig), keyEquivalent: "")
        menu.addItem(withTitle: "Reload config file", action: #selector(AppDelegate.reloadConfig), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(loginMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Stark", action: #selector(AppDelegate.quit), keyEquivalent: "")

        loginMenuItem.state = LaunchAgentHelper.enabled() ? NSOnState : NSOffState

        statusItem.menu = menu
    }

    func about(sender: AnyObject?) {
        NSApp.activate(ignoringOtherApps: true)
        aboutWindowController.showWindow(nil)
    }

    func editConfig(sender: AnyObject?) {
        config.edit()
    }

    func reloadConfig(sender: AnyObject?) {
        context.setup()
    }

    func toggleRunAtLogin(sender: NSMenuItem) {
        if sender.state == NSOnState {
            LaunchAgentHelper.remove()
            sender.state = NSOffState
        } else {
            _ = LaunchAgentHelper.add()
            sender.state = NSOnState
        }
    }

    func quit(sender: AnyObject?) {
        NSApp.terminate(nil)
    }
}
