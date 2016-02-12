import AppKit
import JavaScriptCore

@objc protocol EventHandlerJSExport: JSExport {

}

public class EventHandler: Handler, EventHandlerJSExport {

}