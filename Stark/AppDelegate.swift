import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)

    let config = Config()

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        AccessibilityHelper.askForAccessibilityIfNeeded()

        setupStatusItem()

        config.load()

        NSNotificationCenter
            .defaultCenter()
            .postNotificationName(StarkStartNotification, object: self)
    }

    func setupStatusItem() {
        let image = NSImage(named: "StatusItemIcon")
        image?.template = true

        statusItem.highlightMode = true
        statusItem.image = image

        let menu = NSMenu()
        menu.addItemWithTitle("Edit config file", action: #selector(AppDelegate.editConfig(_:)), keyEquivalent: "")
        menu.addItemWithTitle("Reload config file", action: #selector(AppDelegate.reloadConfig(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItemWithTitle("Quit Stark", action: #selector(AppDelegate.quit(_:)), keyEquivalent: "")

        statusItem.menu = menu
    }

    func editConfig(sender: AnyObject?) {
        config.edit()

    }

    func reloadConfig(sender: AnyObject?) {
        config.load()
    }

    func quit(sender: AnyObject?) {
        NSApp.terminate(nil)
    }
}