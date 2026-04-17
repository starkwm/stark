import ApplicationServices
import Foundation

enum WindowIdentifierEvent {
  case focused
  case moved
  case resized

  func runtimeEvent(windowID: CGWindowID) -> WindowEvent {
    switch self {
    case .focused:
      .focused(windowID)
    case .moved:
      .moved(windowID)
    case .resized:
      .resized(windowID)
    }
  }
}

final class AccessibilityWindowEventResolver {
  private let queue = DispatchQueue(
    label: "dev.tombell.Stark.EventManager.accessibility",
    qos: .userInitiated
  )

  private let postEvent: (RuntimeEvent) -> Void

  init(postEvent: @escaping (RuntimeEvent) -> Void) {
    self.postEvent = postEvent
  }

  func post(
    windowIdentifierEvent event: WindowIdentifierEvent,
    withWindowElement element: AXUIElement
  ) {
    let retainedElement = Unmanaged.passRetained(element)

    queue.async {
      let element = retainedElement.takeRetainedValue()
      let windowID = Window.id(for: element)
      self.postEvent(.window(event.runtimeEvent(windowID: windowID)))
    }
  }

  func post(windowCreatedWithElement element: AXUIElement) {
    let retainedElement = Unmanaged.passRetained(element)

    queue.async {
      let element = retainedElement.takeRetainedValue()
      let windowID = Window.id(for: element)

      guard windowID != 0 else { return }
      guard let pid = Window.pid(for: element) else { return }

      self.postEvent(.window(.created(pid, windowID)))
    }
  }
}
