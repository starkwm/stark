import ApplicationServices
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

enum RuntimeEvent {
  case application(ApplicationEvent)
  case window(WindowEvent)
  case space(SpaceEvent)

  var type: EventType {
    switch self {
    case .application(let event):
      event.type
    case .window(let event):
      event.type
    case .space(let event):
      event.type
    }
  }
}

enum ApplicationEvent {
  case launched(Process)
  case terminated(Process)
  case frontSwitched(Process)

  var type: EventType {
    switch self {
    case .launched:
      .applicationLaunched
    case .terminated:
      .applicationTerminated
    case .frontSwitched:
      .applicationFrontSwitched
    }
  }
}

enum WindowEvent {
  case created(AXUIElement)
  case destroyed(Window)
  case focused(CGWindowID)
  case moved(CGWindowID)
  case resized(CGWindowID)
  case minimized(Window)
  case deminimized(Window)

  var type: EventType {
    switch self {
    case .created:
      .windowCreated
    case .destroyed:
      .windowDestroyed
    case .focused:
      .windowFocused
    case .moved:
      .windowMoved
    case .resized:
      .windowResized
    case .minimized:
      .windowMinimized
    case .deminimized:
      .windowDeminimized
    }
  }
}

enum SpaceEvent {
  case changed(Space)

  var type: EventType {
    switch self {
    case .changed:
      .spaceChanged
    }
  }
}
