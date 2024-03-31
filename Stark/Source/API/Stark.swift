import JavaScriptCore

/// Stark is used for utility functions that are used in the JavaScriptCore runtime.
public class Stark: NSObject, StarkJSExport {
  /// The context for the JavaScriptCore runtime.
  private var context: Context

  /// Iniitliase with the given context.
  init(context: Context) {
    self.context = context
  }

  /// Log a message to the log file.
  public func log(_ message: String) {
    LogHelper.log(message: message)
  }

  /// Reload the configuration file and setup the JavaScriptCore runtime.
  public func reload() {
    context.setup()
  }
}
