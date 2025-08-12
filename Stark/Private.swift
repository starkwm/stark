import Carbon

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSCopyManagedDisplaySpaces")
func SLSCopyManagedDisplaySpaces(_ connectionID: Int32) -> CFArray

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSCopySpacesForWindows")
func SLSCopySpacesForWindows(_ connectionID: Int32, _ mask: Int32, _ windows: CFArray) -> CFArray

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSCopyWindowsWithOptionsAndTags")
func SLSCopyWindowsWithOptionsAndTags(
  _ connectionID: Int32,
  _ owner: UInt32,
  _ spaces: CFArray,
  _ options: UInt32,
  _ setTags: inout UInt64,
  _ clearTags: inout UInt64
) -> CFArray

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSGetActiveSpace")
func SLSGetActiveSpace(_ connectionID: Int32) -> UInt64

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSGetConnectionIDForPSN")
@discardableResult
func SLSGetConnectionIDForPSN(
  _ connectionID: Int32,
  _ psn: inout ProcessSerialNumber,
  _ processConnnectionID: inout Int32
) -> CGError

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSMainConnectionID")
func SLSMainConnectionID() -> Int32

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSManagedDisplayGetCurrentSpace")
func SLSManagedDisplayGetCurrentSpace(_ connectionID: Int32, _ screenID: CFString) -> UInt64

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSSpaceGetType")
func SLSSpaceGetType(_ connectionID: Int32, _ spaceID: UInt64) -> Int32

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorAdvance")
func SLSWindowIteratorAdvance(_ iterator: CFTypeRef) -> Bool

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetAttributes")
func SLSWindowIteratorGetAttributes(_ iterator: CFTypeRef) -> UInt64

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetLevel")
func SLSWindowIteratorGetLevel(_ iterator: CFTypeRef) -> Int

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetParentID")
@discardableResult
func SLSWindowIteratorGetParentID(_ iterator: CFTypeRef) -> UInt32

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetTags")
func SLSWindowIteratorGetTags(_ iterator: CFTypeRef) -> UInt64

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetWindowID")
func SLSWindowIteratorGetWindowID(_ iterator: CFTypeRef) -> UInt32

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowQueryResultCopyWindows")
func SLSWindowQueryResultCopyWindows(_ query: CFTypeRef) -> CFTypeRef

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowQueryWindows")
func SLSWindowQueryWindows(_ connectionID: Int32, _ windows: CFArray, _ count: Int32) -> CFTypeRef

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("_AXUIElementGetWindow")
@discardableResult
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: inout UInt32) -> AXError

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("_AXUIElementCreateWithRemoteToken")
func _AXUIElementCreateWithRemoteToken(_ data: CFData) -> Unmanaged<AXUIElement>?

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("GetNextProcess")
func GetNextProcess(_ psn: inout ProcessSerialNumber) -> OSStatus

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("GetProcessInformation")
@discardableResult
func GetProcessInformation(_ psn: inout ProcessSerialNumber, _ info: inout ProcessInfoRec) -> OSStatus

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("GetProcessPID")
@discardableResult
func GetProcessPID(_ psn: inout ProcessSerialNumber, _ pid: inout pid_t) -> OSStatus

// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("_SLPSGetFrontProcess")
@discardableResult
func _SLPSGetFrontProcess(_ psn: inout ProcessSerialNumber) -> OSStatus
