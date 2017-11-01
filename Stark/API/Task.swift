import AppKit
import JavaScriptCore

@objc
protocol TaskJSExport: JSExport {
    init(path: String, arguments: [String]?, callback: JSValue)

    func terminate()
}

open class Task: Handler, TaskJSExport, HashableJSExport {
    var task: Process

    public required init(path: String, arguments: [String]?, callback: JSValue) {
        task = Process()
        task.launchPath = path
        task.arguments = arguments

        task.standardOutput = Pipe()
        task.standardError = Pipe()

        super.init()

        manageCallback(callback)

        setupTerminationHandler()
        launch()
    }

    func setupTerminationHandler() {
        task.terminationHandler = { [weak self] _ in
            self?.taskDidTerminate()
        }
    }

    func launch() {
        task.launch()
    }

    func terminate() {
        task.terminate()
    }

    @objc
    func taskDidTerminate() {
        perform(#selector(Task.callWithArguments(_:)), on: Thread.main, with: self, waitUntilDone: false, modes: nil)
    }
}
