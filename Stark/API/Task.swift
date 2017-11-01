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

        if let arguments = arguments {
            task.arguments = arguments
        }

        super.init()

        task.terminationHandler = { [weak self] _ in
            self?.taskDidTerminate()
        }

        manageCallback(callback)
        launch()
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
