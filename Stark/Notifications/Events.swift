import Foundation

enum EventType: String {
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
