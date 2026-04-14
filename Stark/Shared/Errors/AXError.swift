enum AXError: Error {
  case accessFailed(String)
  case observerCreationFailed
  case notificationFailed(String)
}
