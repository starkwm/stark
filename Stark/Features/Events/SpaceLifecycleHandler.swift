struct SpaceLifecycleHandler {
  let windowManager: WindowManager
  let dispatcher: RuntimeEventDispatcher

  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    }
  }

  private func spaceChanged(with space: Space) {
    windowManager.refreshWindows()
    dispatcher.emit(.spaceChanged, payload: space, message: "space changed \(space)")
  }
}
