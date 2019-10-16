import AppKit
import JavaScriptCore

public class Task: Handler, TaskJSExport {
    private var task: Process?

    public var id: Int {
        return hashValue
    }

    public var status: Int = -1

    public required init(path: String, arguments: [String]?, callback: JSValue) {
        super.init()

        manageCallback(callback)

        task = Process()

        task?.executableURL = URL(fileURLWithPath: path)
        task?.arguments = arguments

        task?.terminationHandler = { process in
            self.status = Int(process.terminationStatus)
            self.taskDidTerminate()
        }

        task?.launch()
    }

    public func terminate() {
        task?.terminate()
    }

    @objc
    func taskDidTerminate() {
        perform(#selector(call(withArguments:)), on: Thread.main, with: [self], waitUntilDone: false)
    }
}
