import ApplicationServices

struct ApplicationNotifications: OptionSet {
  static let windowCreated = ApplicationNotifications(rawValue: 1 << 0)
  static let windowFocused = ApplicationNotifications(rawValue: 1 << 1)
  static let windowMoved = ApplicationNotifications(rawValue: 1 << 2)
  static let windowResized = ApplicationNotifications(rawValue: 1 << 3)

  static let all: ApplicationNotifications = [
    .windowCreated, .windowFocused, .windowMoved, .windowResized,
  ]

  let rawValue: Int8
}

let applicationNotifications = [
  kAXCreatedNotification,
  kAXFocusedWindowChangedNotification,
  kAXWindowMovedNotification,
  kAXWindowResizedNotification,
]

protocol AXNotificationSet: OptionSet where RawValue == Int8 {
  static var all: Self { get }
}

extension ApplicationNotifications: AXNotificationSet {}
extension WindowNotifications: AXNotificationSet {}

struct AXNotificationRegistrar<Notifications: AXNotificationSet> {
  let notifications: [String]

  func observe(
    observedNotifications: inout Notifications,
    addNotification: (String) -> ApplicationServices.AXError,
    onFailure: (String, ApplicationServices.AXError) -> Void
  ) -> Bool {
    for (index, notification) in notifications.enumerated() {
      let result = addNotification(notification)

      if result == .success || result == .notificationAlreadyRegistered {
        observedNotifications.formUnion(Notifications(rawValue: 1 << index))
      } else {
        onFailure(notification, result)
      }
    }

    return observedNotifications.isSuperset(of: .all)
  }

  func unobserve(
    observedNotifications: inout Notifications,
    removeNotification: (String) -> Void
  ) {
    for (index, notification) in notifications.enumerated() {
      let registeredNotification = Notifications(rawValue: 1 << index)

      guard observedNotifications.isSuperset(of: registeredNotification) else { continue }

      removeNotification(notification)
      observedNotifications.subtract(registeredNotification)
    }
  }
}
