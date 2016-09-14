import Foundation

open class LogHelper {
    open static func log(_ message: String) {
        NSLog("%@", message)

        let dir = URL(fileURLWithPath: NSHomeDirectory())
        let file = dir.appendingPathComponent(".stark.log")

        let formatter = DateFormatter()
        formatter.dateFormat = "[yyyy-MM-dd HH:mm:ss]"

        let log = String(format: "%@ %@", formatter.string(from: Date()), message)

        _ = try? stringAppendLineToURL(log, fileURL: file)
    }

    fileprivate static func stringAppendLineToURL(_ message: String, fileURL: URL) throws {
        try stringAppendToURL(message + "\n", fileURL: fileURL)
    }

    fileprivate static func stringAppendToURL(_ message: String, fileURL: URL) throws {
        let data = message.data(using: String.Encoding.utf8)!
        try dataAppendToURL(data, fileURL: fileURL)
    }

    fileprivate static func dataAppendToURL(_ data: Data, fileURL: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            defer {
                fileHandle.closeFile()
            }

            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }
}
