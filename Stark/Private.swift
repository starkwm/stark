import Carbon

/// Get the display spaces information.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSCopyManagedDisplaySpaces") @discardableResult
func SLSCopyManagedDisplaySpaces(_ connectionID: Int32) -> CFArray

/// Get the spaces that contain the given windows.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSCopySpacesForWindows") @discardableResult
func SLSCopySpacesForWindows(_ connectionID: Int32, _ mask: Int32, _ windows: CFArray) -> CFArray

/// Get the windows on the given spaces.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSCopyWindowsWithOptionsAndTags") @discardableResult
func SLSCopyWindowsWithOptionsAndTags(
  _ connectionID: Int32,
  _ owner: UInt32,
  _ spaces: CFArray,
  _ options: UInt32,
  _ setTags: inout UInt64,
  _ clearTags: inout UInt64
) -> CFArray

/// Get the active space.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSGetActiveSpace") @discardableResult
func SLSGetActiveSpace(_ connectionID: Int32) -> UInt64

/// Get the connection ID for the given process serial number.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSGetConnectionIDForPSN") @discardableResult
func SLSGetConnectionIDForPSN(
  _ connectionID: Int32,
  _ psn: inout ProcessSerialNumber,
  _ processConnnectionID: inout Int32
) -> CGError

/// Get the main connection ID
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSMainConnectionID") @discardableResult
func SLSMainConnectionID() -> Int32

/// Get the current space for the given screen.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSManagedDisplayGetCurrentSpace") @discardableResult
func SLSManagedDisplayGetCurrentSpace(_ connectionID: Int32, _ screenID: CFString) -> UInt64

/// Move windows to a space.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSMoveWindowsToManagedSpace")
func SLSMoveWindowsToManagedSpace(_ connectionID: Int32, _ windows: CFArray, _ spaceID: UInt64)

/// Get the type of space.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSSpaceGetType") @discardableResult
func SLSSpaceGetType(_ connectionID: Int32, _ spaceID: UInt64) -> Int32

/// Iterate over the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorAdvance") @discardableResult
func SLSWindowIteratorAdvance(_ iterator: CFTypeRef) -> Bool

/// Get the window attributes for the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetAttributes") @discardableResult
func SLSWindowIteratorGetAttributes(_ iterator: CFTypeRef) -> UInt64

/// Get the parent ID for the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetParentID") @discardableResult
func SLSWindowIteratorGetParentID(_ iterator: CFTypeRef) -> UInt32

/// Get the tags for the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetTags") @discardableResult
func SLSWindowIteratorGetTags(_ iterator: CFTypeRef) -> UInt64

/// Get the window ID for the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetWindowID") @discardableResult
func SLSWindowIteratorGetWindowID(_ iterator: CFTypeRef) -> UInt32

/// Get the iterator for the given query.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowQueryResultCopyWindows") @discardableResult
func SLSWindowQueryResultCopyWindows(_ query: CFTypeRef) -> CFTypeRef

/// Query for the given windows.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowQueryWindows") @discardableResult
func SLSWindowQueryWindows(_ connectionID: Int32, _ windows: CFArray, _ count: Int32) -> CFTypeRef

/// Set the compat ID for the given space.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSSpaceSetCompatID")
func SLSSpaceSetCompatID(_ connectionID: Int32, _ spaceID: UInt64, _ workspace: Int32) -> CGError

/// Set the window list for the given workspace.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSSetWindowListWorkspace")
func SLSSetWindowListWorkspace(
  _ connectionID: Int32,
  _ windows: UnsafePointer<UInt32>,
  _ window_count: Int32,
  _ workspace: Int32
) -> CGError

/// Get the window ID for the given accessibility UI element.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: inout UInt32) -> AXError

/// Copy the process name.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("CopyProcessName") @discardableResult
func CopyProcessName(_ psn: inout ProcessSerialNumber, _ name: inout CFString) -> OSStatus

/// Iterate over the running processes.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("GetNextProcess") @discardableResult
func GetNextProcess(_ psn: inout ProcessSerialNumber) -> OSStatus

/// Get process information for the given process serial number.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("GetProcessInformation") @discardableResult
func GetProcessInformation(_ psn: inout ProcessSerialNumber, _ info: inout ProcessInfoRec) -> OSStatus

/// Get the process ID for the given process serial number.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("GetProcessPID") @discardableResult
func GetProcessPID(_ psn: inout ProcessSerialNumber, _ pid: inout pid_t) -> OSStatus
