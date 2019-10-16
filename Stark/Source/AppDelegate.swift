import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    let config = Config()

    var context: Context

    override init() {
        context = Context(config: config)
    }

    func applicationDidFinishLaunching(_: Notification) {
        askForAccessibilityIfNeeded()
        setupStatusItem()

        context.setup()

        NotificationCenter.default.post(name: Notification.Name(rawValue: starkDidStartLaunch), object: self)
    }

    func askForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]

        if AXIsProcessTrustedWithOptions(options as CFDictionary?) {
            return
        }

        NSApp.terminate(nil)
    }

    func setupStatusItem() {
        statusItem.button?.image = NSImage(named: "StatusItemIcon")

        let loginMenuItem = NSMenuItem(title: "Launch at login",
                                       action: #selector(toggleRunAtLogin(sender:)),
                                       keyEquivalent: "")

        let menu = NSMenu()
        menu.addItem(withTitle: "Reload config file", action: #selector(reloadConfig(sender:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(loginMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Stark", action: #selector(quit(sender:)), keyEquivalent: "")

        loginMenuItem.state = LaunchAgentHelper.enabled() ? .on : .off

        statusItem.menu = menu
    }

    @objc
    func reloadConfig(sender _: AnyObject?) {
        context.setup()
    }

    @objc
    func toggleRunAtLogin(sender: NSMenuItem) {
        if sender.state == .on {
            LaunchAgentHelper.remove()
            sender.state = .off
        } else {
            LaunchAgentHelper.add()
            sender.state = .on
        }
    }

    @objc
    func quit(sender _: AnyObject?) {
        NSApp.terminate(nil)
    }
}
