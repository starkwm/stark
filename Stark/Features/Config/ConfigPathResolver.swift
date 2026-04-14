import Foundation

struct ConfigPathResolver {
  static let live = ConfigPathResolver(
    resolvePrimaryPath: { paths, fileSystem in
      paths
        .lazy
        .map { ($0 as NSString).resolvingSymlinksInPath }
        .first { fileSystem.fileExists($0) }
        ?? (paths[0] as NSString).resolvingSymlinksInPath
    }
  )

  var resolvePrimaryPath: (_ paths: [String], _ fileSystem: ConfigFileSystem) -> String
}
