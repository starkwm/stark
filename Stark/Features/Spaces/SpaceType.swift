enum SpaceType: Int32 {
  case normal = 0
  case fullscreen = 4
  case unknown
}

extension SpaceType: CustomStringConvertible {
  var description: String {
    switch self {
    case .normal:
      return "normal"
    case .fullscreen:
      return "fullscreen"
    case .unknown:
      return "unknown"
    }
  }
}
