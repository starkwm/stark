import AppKit
import JavaScriptCore

public class Task: Handler, TaskJSExport {
    private var task: Process?
    private var outputData = Data()
    private var errorData = Data()

    public var id: Int { return hashValue }

    public var status: Int = -1
    public var standardOutput: String?
    public var standardError: String?

    public required init(path: String, arguments: [String]?, callback: JSValue?) {
        super.init()

        manageCallback(callback)

        task = Process()
        task?.executableURL = URL(fileURLWithPath: path)
        task?.arguments = arguments ?? []
        task?.standardOutput = Pipe()
        task?.standardError = Pipe()

        setupReadabilityHandlers()
        setupTerminationHandler()

        launch()
    }

    public func terminate() {
        task?.terminate()
    }

    private func setupReadabilityHandlers() {
        if let stdout = task?.standardOutput as? Pipe {
            stdout.fileHandleForReading.readabilityHandler = { file in
                self.outputData.append(file.availableData)
            }
        }

        if let stderr = task?.standardError as? Pipe {
            stderr.fileHandleForReading.readabilityHandler = { file in
                self.errorData.append(file.availableData)
            }
        }
    }

    private func setupTerminationHandler() {
        task?.terminationHandler = { process in
            if let stdout = self.task?.standardOutput as? Pipe {
                stdout.fileHandleForReading.readabilityHandler = nil
            }

            if let stderr = self.task?.standardError as? Pipe {
                stderr.fileHandleForReading.readabilityHandler = nil
            }

            self.status = Int(process.terminationStatus)

            self.standardOutput = String(data: self.outputData, encoding: .utf8)
            self.standardError = String(data: self.errorData, encoding: .utf8)

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
