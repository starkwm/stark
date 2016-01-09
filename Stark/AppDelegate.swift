import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)

    let config = Config()

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        AccessibilityHelper.askForAccessibilityIfNeeded()

        setupStatusItem()

        config.load()
    }

    func applicationWillTerminate(aNotification: NSNotification) {

    }

    func setupStatusItem() {
        let image = NSImage(named: "StatusItemIcon")
        image?.template = true

        statusItem.highlightMode = true
        statusItem.image = image

        let menu = NSMenu()
        menu.addItemWithTitle("Reload", action: "reload:", keyEquivalent: "")
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItemWithTitle("Quit Stark", action: "quit:", keyEquivalent: "")

        statusItem.menu = menu
    }

    func reload(sender: AnyObject?) {
        config.load()
    }

    func quit(sender: AnyObject?) {
        NSApp.terminate(nil)
    }
}
