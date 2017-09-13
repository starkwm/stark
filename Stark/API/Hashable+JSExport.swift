import Foundation
import JavaScriptCore

@objc
protocol HashableJSExport: JSExport {
    var hashValue: Int { get }
}
