import AppKit

class StarkStatusItem {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var config: Config
    var context: Context

    init() {
        config = Config()
        context = Context(config: config)
        context.setup()
    }

    func setup() {
        statusItem.button?.image = NSImage(named: "StatusItemIcon")

        let menu = NSMenu()

        let reloadConfigItem = NSMenuItem(title: "Reload configuration",
                                          action: #selector(reloadConfig(sender:)),
                                          keyEquivalent: "")
        reloadConfigItem.target = self

        let loginItem = NSMenuItem(title: "Launch at login",
                                   action: #selector(toggleRunAtLogin(sender:)),
                                   keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LaunchAgentHelper.enabled() ? .on : .off

        let quitItem = NSMenuItem(title: "Quit Stark",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "")

        menu.addItem(reloadConfigItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)

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
}
