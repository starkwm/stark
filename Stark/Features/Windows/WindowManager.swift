import Carbon

protocol WindowManagerProcessListing {
  func all() -> [Process]
}

protocol WindowManagerWorkspaceObserving {
  func isObservable(_ process: Process) -> Bool
  func observeActivationPolicy(_ process: Process)
}

/// Manages all windows and applications in the system.
/// Coordinates window discovery, observation, and lifecycle management.
final class WindowManager {
  static let shared = WindowManager()

  private let processManager: WindowManagerProcessListing
  private let workspace: WindowManagerWorkspaceObserving
  private let applications = ManagedApplicationStore()
  private let refreshQueue = UnresolvedWindowRefreshQueue()
  private let resolver = RemoteWindowResolver()
  private let windows = ManagedWindowStore()

  init(
    processManager: WindowManagerProcessListing = ProcessManager.shared,
    workspace: WindowManagerWorkspaceObserving = Workspace.shared
  ) {
    self.processManager = processManager
    self.workspace = workspace
  }

  /// Initializes window management by observing all running applications.
  func start() {
    for process in processManager.all() {
      guard workspace.isObservable(process) else {
        log("application is not observable \(process)", level: .warn)
        workspace.observeActivationPolicy(process)
        continue
      }

      guard let application = Application(for: process) else {
        log("could not create application for process \(process)", level: .warn)
        continue
      }

      switch application.observe() {
      case .success:
        break
      case .failure:
        application.unobserve()
        continue
      }

      add(application: application)
      reconcileWindows(for: application, mode: .initialDiscovery)
    }
  }

  /// Adds an application to management.
  /// - Parameter application: The application to add
  func add(application: Application) {
    applications.add(application)
  }

  /// Removes an application from management and cleans up its resources.
  /// - Parameter application: The application to remove
  func remove(application: Application) {
    refreshQueue.remove(application)
    applications.remove(application)
  }

  /// Creates and manages a new window from an accessibility element.
  /// - Parameters:
  ///   - application: The application that owns the window
  ///   - element: The AXUIElement representing the window
  /// - Returns: The created Window, or nil if invalid/unobservable
  @discardableResult
  func addWindow(for application: Application, with element: AXUIElement) -> Window? {
    let window = Window(with: element, for: application)

    guard window.subrole != nil else { return nil }

    guard window.observe() else {
      window.unobserve()
      return nil
    }

    windows.add(window)

    return window
  }

  @discardableResult
  func addWindows(for application: Application) -> [Window] {
    let elements = application.windowElements()
    var result = [Window]()

    for element in elements {
      let windowID = Window.id(for: element)

      guard windowID != 0, windows.window(by: windowID) == nil else { continue }

      if let window = addWindow(for: application, with: element) {
        result.append(window)
      }
    }

    return result
  }

  /// Removes a window from management.
  /// - Parameter windowID: The ID of the window to remove
  func remove(by windowID: CGWindowID) {
    windows.remove(windowID: windowID)
  }

  /// Looks up an application by its process ID.
  /// - Parameter pid: The process identifier
  /// - Returns: The application, or nil if not found
  func application(by pid: pid_t) -> Application? {
    applications.application(by: pid)
  }

  /// Looks up an application by its name.
  /// - Parameter name: The application name
  /// - Returns: The application, or nil if not found
  func application(by name: String) -> Application? {
    applications.application(named: name)
  }

  /// Returns all managed applications.
  /// - Returns: Array of all applications
  func allApplications() -> [Application] {
    applications.all()
  }

  /// Looks up a window by its ID.
  /// - Parameter id: The window identifier
  /// - Returns: The window, or nil if not found
  func window(by id: CGWindowID) -> Window? {
    windows.window(by: id)
  }

  /// Returns all windows belonging to an application.
  /// - Parameter application: The application to query
  /// - Returns: Array of windows for that application
  func allWindows(for application: Application) -> [Window] {
    windows.windows(for: application)
  }

  func allWindows() -> [Window] {
    windows.all()
  }

  /// Retries window discovery for every application still waiting on remote resolution.
  func refreshWindows() {
    for application in refreshQueue.all() {
      refreshWindows(for: application)
    }
  }

  /// Retries deferred window discovery for a single application.
  func refreshWindows(for application: Application) {
    guard refreshQueue.contains(application) else { return }

    log("application has windows that are not yet resolved \(application)", level: .info)
    _ = reconcileWindows(for: application, mode: .refreshAttempt)
  }

  /// Reconciles AX-reported windows against the window server list and runs the fallback resolver.
  @discardableResult
  private func reconcileWindows(
    for application: Application,
    mode: WindowDiscoveryMode
  ) -> Bool {
    let globalWindowList = application.windowIdentifiers()
    let elements = application.windowElements()

    var emptyCount = 0

    for element in elements {
      let windowID = Window.id(for: element)

      if windowID == 0 {
        emptyCount += 1
        continue
      }

      if windows.window(by: windowID) == nil {
        addWindow(for: application, with: element)
      }
    }

    let resolvedWindowCount = elements.count - emptyCount

    guard globalWindowList.count != resolvedWindowCount else {
      if mode == .refreshAttempt {
        log("all windows resolved \(application)", level: .info)
        refreshQueue.remove(application)
        return true
      }

      return false
    }

    var unresolvedWindowIDs = globalWindowList.filter { windows.window(by: $0) == nil }
    guard !unresolvedWindowIDs.isEmpty else { return false }

    log(
      "application has windows that are not resolved, attempting workaround \(application)",
      level: .info
    )

    resolver.resolve(
      unresolvedWindowIDs: &unresolvedWindowIDs,
      for: application,
      addWindow: { [weak self] element in
        guard let self else { return }
        _ = self.addWindow(for: application, with: element)
      }
    )

    switch mode {
    case .initialDiscovery:
      if !unresolvedWindowIDs.isEmpty {
        log("workaround failed to resolve all windows \(application)", level: .warn)
        refreshQueue.enqueue(application)
      }

    case .refreshAttempt:
      if unresolvedWindowIDs.isEmpty {
        log("workaround successfully resolved all windows \(application)", level: .info)
        refreshQueue.remove(application)
        return true
      }
    }

    return false
  }
}

extension ProcessManager: WindowManagerProcessListing {}
extension Workspace: WindowManagerWorkspaceObserving {}

private enum WindowDiscoveryMode {
  case initialDiscovery
  case refreshAttempt
}

private final class ManagedApplicationStore {
  private var applications = [pid_t: Application]()

  func add(_ application: Application) {
    applications[application.processID] = application
  }

  func remove(_ application: Application) {
    applications.removeValue(forKey: application.processID)
  }

  func application(by pid: pid_t) -> Application? {
    applications[pid]
  }

  func application(named name: String) -> Application? {
    applications.values.first { $0.name == name }
  }

  func all() -> [Application] {
    Array(applications.values)
  }
}

private final class ManagedWindowStore {
  private var windows = [CGWindowID: Window]()

  func add(_ window: Window) {
    windows[window.id] = window
  }

  func remove(windowID: CGWindowID) {
    windows.removeValue(forKey: windowID)
  }

  func window(by id: CGWindowID) -> Window? {
    windows[id]
  }

  func windows(for application: Application) -> [Window] {
    windows.values.filter { $0.application == application }
  }

  func all() -> [Window] {
    Array(windows.values)
  }
}

private final class UnresolvedWindowRefreshQueue {
  private var applications = [pid_t: Application]()

  func enqueue(_ application: Application) {
    applications[application.processID] = application
  }

  func remove(_ application: Application) {
    applications.removeValue(forKey: application.processID)
  }

  func contains(_ application: Application) -> Bool {
    applications[application.processID] != nil
  }

  func all() -> [Application] {
    Array(applications.values)
  }
}

private final class RemoteWindowResolver {
  func resolve(
    unresolvedWindowIDs: inout [CGWindowID],
    for application: Application,
    addWindow: (AXUIElement) -> Void
  ) {
    for id in 0...0x7fff {
      guard !unresolvedWindowIDs.isEmpty else { break }

      let token = createRemoteToken(for: application.processID, with: id)

      guard
        let element = _AXUIElementCreateWithRemoteToken(token)?.takeRetainedValue(),
        Window.isWindow(element),
        let windowID = Window.validID(for: element)
      else {
        continue
      }

      if let index = unresolvedWindowIDs.firstIndex(of: windowID) {
        unresolvedWindowIDs.remove(at: index)
        addWindow(element)
        log("resolved window \(windowID) for \(application)", level: .info)
      }
    }
  }

  private func createRemoteToken(for pid: pid_t, with id: Int) -> CFData {
    var token = Data()

    token.append(contentsOf: withUnsafeBytes(of: pid) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })
    token.append(contentsOf: withUnsafeBytes(of: id) { Data($0) })

    return token as CFData
  }
}
