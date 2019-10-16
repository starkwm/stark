import AppKit
import JavaScriptCore

public class Task: Handler, TaskJSExport {
    private var task: Process?

    public var id: Int {
        return hashValue
    }

    public var status: Int = -1

    public required init(path: String, arguments: [String]?, callback: JSValue?) {
        super.init()

        manageCallback(callback)

        task = Process()

        task?.executableURL = URL(fileURLWithPath: path)
        task?.arguments = arguments

        setupTerminationHandler()

        launch()
    }

    public func terminate() {
        task?.terminate()
    }

    private func setupTerminationHandler() {
        task?.terminationHandler = { process in
            self.status = Int(process.terminationStatus)
            self.taskDidTerminate()
        }
    }

    private func launch() {
        do {
            try task?.run()
        } catch {
            let message = String(format: "Error: task run failed running %@ with arguments '%@' (%@)",
                                 task?.executableURL?.path ?? "",
                                 task?.arguments?.joined(separator: " ") ?? [],
                                 error.localizedDescription)
            LogHelper.log(message: message)
        }
    }

    @objc
    func taskDidTerminate() {
        perform(#selector(call(withArguments:)), on: Thread.main, with: [self], waitUntilDone: false)
    }
}
