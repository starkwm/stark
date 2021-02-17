import Foundation

enum LogHelper {
    static func log(message: String) {
        NSLog("%@", message)

        let dir = URL(fileURLWithPath: NSHomeDirectory())
        let file = dir.appendingPathComponent(".stark.log")

        let formatter = DateFormatter()
        formatter.dateFormat = "[yyyy-MM-dd HH:mm:ss]"

        let log = String(format: "%@ %@", formatter.string(from: Date()), message)

        _ = try? stringAppendLineToURL(message: log, fileURL: file)
    }

    static func stringAppendLineToURL(message: String, fileURL: URL) throws {
        try stringAppendToURL(message: message + "\n", fileURL: fileURL)
    }

    static func stringAppendToURL(message: String, fileURL: URL) throws {
        let data = message.data(using: String.Encoding.utf8)!
        try dataAppendToURL(data: data, fileURL: fileURL)
    }

    static func dataAppendToURL(data: Data, fileURL: URL) throws {
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
