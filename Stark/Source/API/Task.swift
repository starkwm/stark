import AppKit
import JavaScriptCore

public class Task: Handler, TaskJSExport {
    private var task: Process?

    public var id: Int {
        return hashValue
    }

    public var status: Int = -1

    public required init(path: String, arguments: [String]?, callback _: JSValue) {
        super.init()

        task = Process()

        task?.executableURL = URL(fileURLWithPath: path)
        task?.arguments = arguments

        task?.terminationHandler = { process in
            print("didFinish: \(!process.isRunning) - \(process.terminationStatus)")
            self.status = Int(process.terminationStatus)
        }

        task?.launch()
    }
}
