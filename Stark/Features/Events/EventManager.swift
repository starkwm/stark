import ApplicationServices
import Carbon
import Foundation

protocol EventWorkspaceManaging {
  func isFinishedLaunching(_ process: Process) -> Bool
  func observeFinishedLaunching(_ process: Process)
  func unobserveFinishedLaunching(_ process: Process)
  func isObservable(_ process: Process) -> Bool
  func observeActivationPolicy(_ process: Process)
  func unobserveActivationPolicy(_ process: Process)
}

protocol EventWindowManaging {
  func add(application: Application)
  func remove(application: Application)
  func application(by pid: pid_t) -> Application?
  func addWindow(for application: Application, with element: AXUIElement) -> Window?
  func addWindows(for application: Application) -> [Window]
  func remove(by windowID: CGWindowID)
  func window(by id: CGWindowID) -> Window?
  func allWindows(for application: Application) -> [Window]
  func refreshWindows()
  func refreshWindows(for application: Application)
}

protocol EventProcessLookup {
  func find(by psn: ProcessSerialNumber) -> Process?
}

final class EventManager {
  static let shared = EventManager()

  private let queue = OperationQueue.main
  private let workspace: EventWorkspaceManaging
  private let windowManager: EventWindowManaging
  private let processLookup: EventProcessLookup
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
    workspace: EventWorkspaceManaging = Workspace.shared,
    windowManager: EventWindowManaging = WindowManager.shared,
    processLookup: EventProcessLookup = ProcessManager.shared,
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

extension Workspace: EventWorkspaceManaging {}
extension WindowManager: EventWindowManaging {}
extension ProcessManager: EventProcessLookup {}
