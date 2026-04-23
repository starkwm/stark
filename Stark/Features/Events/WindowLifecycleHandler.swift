import ApplicationServices

struct WindowLifecycleHandler {
  let windowManager: WindowManager
  let dispatcher: RuntimeEventDispatcher

  func handle(_ event: WindowEvent) {
    switch event {
    case .created(let pid, let windowID):
      windowCreated(for: pid, with: windowID)
    case .destroyed(let window):
      windowDestroyed(with: window)
    case .focused(let windowID):
      windowFocused(with: windowID)
    case .moved(let windowID):
      windowMoved(with: windowID)
    case .resized(let windowID):
      windowResized(with: windowID)
    case .minimized(let window):
      windowMinimized(with: window)
    case .deminimized(let window):
      windowDeminimized(with: window)
    }
  }

  private func windowCreated(for pid: pid_t, with windowID: CGWindowID) {
    guard windowManager.window(by: windowID) == nil else { return }
    guard let application = windowManager.application(by: pid) else { return }

    let element = application.windowElements().first { Window.validID(for: $0) == windowID }
    let window: Window?

    if let element {
      window = windowManager.addWindow(for: application, with: element)
    } else {
      _ = windowManager.addWindows(for: application)
      window = windowManager.window(by: windowID)
    }

    guard let window else { return }

    dispatcher.emit(.windowCreated, payload: window, message: "window created \(window)")
  }

  private func windowDestroyed(with window: Window) {
    guard window.id != 0 else { return }

    dispatcher.emit(.windowDestroyed, payload: window, message: "window destroyed \(window)")

    windowManager.remove(by: window.id)
    window.invalidate()
  }

  private func windowFocused(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = windowManager.window(by: windowID) else { return }

    dispatcher.emit(.windowFocused, payload: window, message: "window focused \(window)")
  }

  private func windowMoved(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = windowManager.window(by: windowID) else { return }

    dispatcher.emit(.windowMoved, payload: window, message: "window moved \(window)")
  }

  private func windowResized(with windowID: CGWindowID) {
    guard windowID != 0 else { return }
    guard let window = windowManager.window(by: windowID) else { return }

    dispatcher.emit(.windowResized, payload: window, message: "window resized \(window)")
  }

  private func windowMinimized(with window: Window) {
    dispatcher.emit(.windowMinimized, payload: window, message: "window minimized \(window)")
  }

  private func windowDeminimized(with window: Window) {
    dispatcher.emit(
      .windowDeminimized,
      payload: window,
      message: "window deminimized \(window)"
    )
  }
}
