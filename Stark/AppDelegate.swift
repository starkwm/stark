import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)

    var config: Config
    var context: Context

    var aboutWindowController = AboutWindowController(windowNibName: "AboutWindow")

    override init() {
        config = Config()
        context = Context(config: config)
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        AccessibilityHelper.askForAccessibilityIfNeeded()

        setupStatusItem()

        context.setup()

        NSNotificationCenter
            .defaultCenter()
            .postNotificationName(starkStartNotification, object: self)
    }

    func setupStatusItem() {
        let image = NSImage(named: "StatusItemIcon")
        image?.template = true

        statusItem.highlightMode = true
        statusItem.image = image

        let loginMenuItem = NSMenuItem(title: "Run at login", action: #selector(AppDelegate.toggleRunAtLogin), keyEquivalent: "")

        let menu = NSMenu()
        menu.addItemWithTitle("About", action: #selector(AppDelegate.about), keyEquivalent: "")
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItemWithTitle("Edit config file", action: #selector(AppDelegate.editConfig), keyEquivalent: "")
        menu.addItemWithTitle("Reload config file", action: #selector(AppDelegate.reloadConfig), keyEquivalent: "")
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItem(loginMenuItem)
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItemWithTitle("Quit Stark", action: #selector(AppDelegate.quit), keyEquivalent: "")

        loginMenuItem.state = LaunchAgentHelper.enabled() ? NSOnState : NSOffState

        statusItem.menu = menu
    }

    func about(sender: AnyObject?) {
        NSApp.activateIgnoringOtherApps(true)
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
            LaunchAgentHelper.add()
            sender.state = NSOnState
        }
    }

    func quit(sender: AnyObject?) {
        NSApp.terminate(nil)
    }
}
