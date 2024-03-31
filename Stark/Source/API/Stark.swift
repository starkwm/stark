import AppKit
import JavaScriptCore

public class Stark: NSObject, StarkJSExport {
  private var config: Config
  private var context: Context

  init(config: Config, context: Context) {
    self.config = config
    self.context = context
  }

  public func log(_ message: String) {
    LogHelper.log(message: message)
  }

  public func reload() {
    context.setup()
  }
}
