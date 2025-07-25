import AppKit

let logJavaScriptExceptionsKey = "logJavaScriptExceptions"

class StarkStatusItem {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

  func setup() {
    statusItem.button?.image = NSImage(named: NSImage.Name("StatusItemIcon"))

    let menu = NSMenu()

    let loginItem = NSMenuItem(
      title: "Launch at login",
      action: #selector(toggleRunAtLogin(sender:)),
      keyEquivalent: ""
    )
    loginItem.target = self
    loginItem.state = LaunchAgentHelper.enabled() ? .on : .off

    let logItem = NSMenuItem(
      title: "Enable logging",
      action: #selector(toggleLogging(sender:)),
      keyEquivalent: ""
    )
    logItem.target = self
    logItem.state = UserDefaults.standard.bool(forKey: "enableLogging") ? .on : .off

    let quitItem = NSMenuItem(
      title: "Quit Stark",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: ""
    )

    menu.addItem(loginItem)
    menu.addItem(logItem)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(quitItem)

    statusItem.menu = menu
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
  func toggleLogging(sender: NSMenuItem) {
    if sender.state == .on {
      UserDefaults.standard.set(false, forKey: "enableLogging")
      sender.state = .off
    } else {
      UserDefaults.standard.set(true, forKey: "enableLogging")
      sender.state = .on
    }

    UserDefaults.standard.synchronize()
  }
}
