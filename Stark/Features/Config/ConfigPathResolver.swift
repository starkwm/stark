import Foundation

struct ConfigPathResolver {
  var resolvePrimaryPath: (_ paths: [String], _ fileSystem: ConfigFileSystem) -> String

  static let live = ConfigPathResolver(
    resolvePrimaryPath: { paths, fileSystem in
      paths
        .lazy
        .map { ($0 as NSString).resolvingSymlinksInPath }
        .first { fileSystem.fileExists($0) }
        ?? (paths[0] as NSString).resolvingSymlinksInPath
    }
  )
}
