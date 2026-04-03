import Foundation

struct ConfigFileWatcher {
  var startMonitoring:
    (
      _ path: String,
      _ queue: DispatchQueue,
      _ reloadHandler: @escaping (_ needsMonitorRestart: Bool) -> Void
    ) -> Result<DispatchSourceFileSystemObject, FileError>

  static let live = ConfigFileWatcher(
    startMonitoring: { path, queue, reloadHandler in
      let file = NSURL.fileURL(withPath: path)
      let fd = open(file.path, O_EVTONLY)

      guard fd >= 0 else {
        return .failure(.monitorFailed("could not open config file for monitoring"))
      }

      let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd,
        eventMask: [.write, .delete, .rename],
        queue: queue
      )

      source.setEventHandler { [weak source] in
        guard let source else { return }

        let events = source.data
        let needsMonitorRestart = events.contains(.delete) || events.contains(.rename)
        let needsReload = needsMonitorRestart || events.contains(.write)

        if needsReload {
          reloadHandler(needsMonitorRestart)
        }
      }

      source.setCancelHandler {
        close(fd)
      }

      source.resume()

      return .success(source)
    }
  )
}
