import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        AccessibilityHelper.askForAccessibilityIfNeeded()

        setupStatusItem()

        let config = Config()
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
        menu.addItemWithTitle("Quit Stark", action: "quit:", keyEquivalent: "")

        statusItem.menu = menu
    }

    func quit(sender: AnyObject?) {
        NSApp.terminate(nil)
    }
}
