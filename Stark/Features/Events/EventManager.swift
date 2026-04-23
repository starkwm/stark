import ApplicationServices
import Carbon
import Foundation

final class EventManager {
  static let shared = EventManager()

  private let queue = OperationQueue.main
  private let workspace: Workspace
  private let windowManager: WindowManager
  private let processLookup: ProcessManager
  private let listenerProvider: EventListenerProviding

  private lazy var dispatcher = RuntimeEventDispatcher(listenerProvider: listenerProvider)
  private lazy var applicationHandler = ApplicationLifecycleHandler(
    workspace: workspace,
    windowManager: windowManager,
    processLookup: processLookup,
    dispatcher: dispatcher,
    postEvent: { [weak self] event in
      self?.post(event)
    }
  )
  private lazy var windowHandler = WindowLifecycleHandler(
    windowManager: windowManager,
    dispatcher: dispatcher
  )
  private lazy var spaceHandler = SpaceLifecycleHandler(
    windowManager: windowManager,
    dispatcher: dispatcher
  )
  private lazy var accessibilityResolver = AccessibilityWindowEventResolver(
    postEvent: { [weak self] event in
      self?.post(event)
    }
  )

  init(
    workspace: Workspace = .shared,
    windowManager: WindowManager = .shared,
    processLookup: ProcessManager = .shared,
    listenerProvider: EventListenerProviding = ConfigSessionStore.shared
  ) {
    self.workspace = workspace
    self.windowManager = windowManager
    self.processLookup = processLookup
    self.listenerProvider = listenerProvider
  }

  func post(_ event: RuntimeEvent) {
    queue.addOperation { self.handle(event) }
  }

  func post(
    windowIdentifierEvent event: WindowIdentifierEvent,
    withWindowElement element: AXUIElement
  ) {
    accessibilityResolver.post(windowIdentifierEvent: event, withWindowElement: element)
  }

  func post(windowCreatedWithElement element: AXUIElement) {
    accessibilityResolver.post(windowCreatedWithElement: element)
  }

  private func handle(_ event: RuntimeEvent) {
    switch event {
    case .application(let event):
      applicationHandler.handle(event)
    case .window(let event):
      windowHandler.handle(event)
    case .space(let event):
      spaceHandler.handle(event)
    }
  }
}
