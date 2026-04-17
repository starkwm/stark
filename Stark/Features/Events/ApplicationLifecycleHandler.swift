import Foundation

struct ApplicationLifecycleHandler {
  let workspace: EventWorkspaceManaging
  let windowManager: EventWindowManaging
  let processLookup: EventProcessLookup
  let dispatcher: RuntimeEventDispatcher
  let postEvent: (RuntimeEvent) -> Void

  func handle(_ event: ApplicationEvent) {
    switch event {
    case .launched(let process):
      applicationLaunched(for: process)
    case .terminated(let process):
      applicationTerminated(for: process)
    case .frontSwitched(let process):
      applicationFrontSwitched(for: process)
    }
  }

  private func applicationLaunched(for process: Process) {
    if process.terminated {
      log("application terminated during launch \(process)")
      return
    }

    if !workspace.isFinishedLaunching(process) {
      log("application has not finished launching \(process)")
      workspace.observeFinishedLaunching(process)

      guard workspace.isFinishedLaunching(process) else { return }
      workspace.unobserveFinishedLaunching(process)
    }

    if !workspace.isObservable(process) {
      log("application is not observable \(process)")
      workspace.observeActivationPolicy(process)

      guard workspace.isObservable(process) else { return }
      workspace.unobserveActivationPolicy(process)
    }

    guard windowManager.application(by: process.pid) == nil else { return }

    guard let application = Application(for: process) else {
      log("could not create application for process \(process)", level: .warn)
      return
    }

    switch application.observe() {
    case .success:
      break
    case .failure(let error):
      log("could not observe application \(application): \(error)", level: .warn)
      application.unobserve()

      if application.retryObserving {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          guard let process = processLookup.find(by: process.psn) else { return }
          postEvent(.application(.launched(process)))
        }
      }

      return
    }

    windowManager.add(application: application)
    _ = windowManager.addWindows(for: application)

    dispatcher.emit(
      .applicationLaunched,
      payload: application,
      message: "application launched \(application)"
    )
  }

  private func applicationTerminated(for process: Process) {
    workspace.unobserveActivationPolicy(process)
    workspace.unobserveFinishedLaunching(process)

    guard let application = windowManager.application(by: process.pid) else { return }

    dispatcher.emit(
      .applicationTerminated,
      payload: application,
      message: "application terminated \(application)"
    )

    windowManager.remove(application: application)

    let windows = windowManager.allWindows(for: application)

    for window in windows {
      windowManager.remove(by: window.id)
      window.invalidate()
    }

    application.unobserve()
  }

  private func applicationFrontSwitched(for process: Process) {
    guard let application = windowManager.application(by: process.pid) else { return }

    windowManager.refreshWindows(for: application)

    dispatcher.emit(
      .applicationFrontSwitched,
      payload: application,
      message: "frontmost application switched \(application)"
    )
  }
}
