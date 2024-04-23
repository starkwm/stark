import Carbon

struct ApplicationNotifications: OptionSet {
  static let windowCreated = ApplicationNotifications(rawValue: 1 << 0)
  static let windowFocused = ApplicationNotifications(rawValue: 1 << 1)
  static let windowMoved = ApplicationNotifications(rawValue: 1 << 2)
  static let windowResized = ApplicationNotifications(rawValue: 1 << 3)

  static let all: ApplicationNotifications = [.windowCreated, .windowFocused, .windowMoved, .windowResized]

  let rawValue: Int8
}

let applicationNotifications = [
  kAXCreatedNotification,
  kAXFocusedWindowChangedNotification,
  kAXWindowMovedNotification,
  kAXWindowResizedNotification,
]
