import JavaScriptCore

@objc
protocol SpaceJSExport: JSExport {
    static func active() -> Space
}

open class Space: NSObject {
    private var identifier: CGSSpaceID

    init(identifier: UInt) {
        self.identifier = identifier
    }

    open static func active() -> Space {
        return Space(identifier: CGSGetActiveSpace(CGSMainConnectionID()))
    }
}
