/// The key of the user defaults option for logging exceptions from the JavaScript context.
let logJavaScriptExceptionsKey = "logJavaScriptExceptions"

/// Manages the status bar item.
class StarkStatusItem {
  /// The status item in the status bar.
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

  /// The context for the JavaScript environment, used for reloading the configuration.
  private var config: Config

  /// Initialise with the JavaScript context.
  init(config: Config) {
    self.config = config
  }

  /// Set up the status bar item and menu.
  func setup() {
    statusItem.button?.image = NSImage(named: NSImage.Name("StatusItemIcon"))

    let menu = NSMenu()

    let reloadConfigItem = NSMenuItem(
      title: "Reload configuration",
      action: #selector(reloadConfig(sender:)),
      keyEquivalent: ""
    )
    reloadConfigItem.target = self

    let loginItem = NSMenuItem(
      title: "Launch at login",
      action: #selector(toggleRunAtLogin(sender:)),
      keyEquivalent: ""
    )
    loginItem.target = self
    loginItem.state = LaunchAgentHelper.enabled() ? .on : .off

    let quitItem = NSMenuItem(
      title: "Quit Stark",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: ""
    )

    menu.addItem(reloadConfigItem)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(loginItem)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(quitItem)

    statusItem.menu = menu
  }

  /// Reload the configuration file.
  @objc
  func reloadConfig(sender _: AnyObject?) {
    config.execute()
  }

  /// Toggle running at login.
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
