import Carbon

struct WindowNotifications: OptionSet {
  static let windowDestroyed = WindowNotifications(rawValue: 1 << 0)
  static let windowMinimized = WindowNotifications(rawValue: 1 << 1)
  static let windowDeminimized = WindowNotifications(rawValue: 1 << 2)

  static let all: WindowNotifications = [.windowDestroyed, .windowMinimized, .windowDeminimized]

  let rawValue: Int8
}

let windowNotifications = [
  kAXUIElementDestroyedNotification,
  kAXWindowMiniaturizedNotification,
  kAXWindowDeminiaturizedNotification,
]
