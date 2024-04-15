import Foundation

extension String {
  init(_ fourCharCode: FourCharCode) {
    self = NSFileTypeForHFSTypeCode(fourCharCode).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
  }
}
