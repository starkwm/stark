import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var config: Config
    var context: Context

    override init() {
        config = Config()
        context = Context(config: config)
    }

    func applicationDidFinishLaunching(_: Notification) {
        askForAccessibilityIfNeeded()
        setupStatusItem()

        context.setup()

        NotificationCenter.default.post(name: Notification.Name(rawValue: starkStartNotification), object: self)
    }

    func askForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]

        if AXIsProcessTrustedWithOptions(options as CFDictionary?) {
            return
        }

        NSApp.terminate(nil)
    }

    func setupStatusItem() {
        let image = NSImage(named: "StatusItemIcon")
        image?.isTemplate = true

        statusItem.button?.image = image

        let loginMenuItem = NSMenuItem(title: "Launch at login",
                                       action: #selector(AppDelegate.toggleRunAtLogin),
                                       keyEquivalent: "")

        let menu = NSMenu()
        menu.addItem(withTitle: "Reload config file", action: #selector(AppDelegate.reloadConfig), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(loginMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Stark", action: #selector(AppDelegate.quit), keyEquivalent: "")

        loginMenuItem.state = LaunchAgentHelper.enabled() ? NSControl.StateValue.on : NSControl.StateValue.off

        statusItem.menu = menu
    }

    @objc
    func reloadConfig(sender _: AnyObject?) {
        context.setup()
    }

    @objc
    func toggleRunAtLogin(sender: NSMenuItem) {
        if sender.state == NSControl.StateValue.on {
            LaunchAgentHelper.remove()
            sender.state = NSControl.StateValue.off
        } else {
            LaunchAgentHelper.add()
            sender.state = NSControl.StateValue.on
        }
    }

    @objc
    func quit(sender _: AnyObject?) {
        NSApp.terminate(nil)
    }
}
