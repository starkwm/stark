import Foundation

enum EventType: String, CaseIterable {
  case applicationLaunched
  case applicationTerminated
  case applicationFrontSwitched

  case windowCreated
  case windowDestroyed
  case windowFocused
  case windowMoved
  case windowResized
  case windowMinimized
  case windowDeminimized

  case spaceChanged
}

let events = EventType.allCases.reduce([EventType: Notification.Name]()) {
  (dict, event) -> [EventType: Notification.Name] in
  var dict = dict
  dict[event] = Notification.Name(event.rawValue)
  return dict
}
