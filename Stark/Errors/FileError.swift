import Foundation

enum FileError: Error {
  case notFound(String)
  case readFailed(String)
  case monitorFailed(String)
}
