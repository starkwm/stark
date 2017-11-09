@import Foundation;

/* XXX: Undocumented private typedefs for CGSSpace */

typedef NSUInteger CGSConnectionID;
typedef NSUInteger CGSSpaceID;

typedef enum {
    kCGSSpaceIncludesCurrent = 1 << 0,
    kCGSSpaceIncludesOthers = 1 << 1,
    kCGSSpaceIncludesUser = 1 << 2,

    kCGSAllSpacesMask = kCGSSpaceIncludesCurrent | kCGSSpaceIncludesOthers | kCGSSpaceIncludesUser

} CGSSpaceMask;

typedef enum {
    kCGSSpaceUser,
    kCGSSpaceFullScreen = 4

} CGSSpaceType;

// XXX: Undocumented private API to get the CGSConnectionID for the default connection for this process
CGSConnectionID CGSMainConnectionID();

// XXX: Undocumented private API to get the CGSSpaceID for the active space
CGSSpaceID CGSGetActiveSpace(CGSConnectionID connection);

// XXX: Undocumented private API to get the CGSSpaceID for the current space for a given screen (UUID)
CGSSpaceID CGSManagedDisplayGetCurrentSpace(CGSConnectionID connection, CFStringRef screenId);

// XXX: Undocumented private API to get the CGSSpaceIDs for all spaces in order
CFArrayRef CGSCopyManagedDisplaySpaces(CGSConnectionID connection);

// XXX: Undocumented private API to get the CGSSpaceIDs for the given windows (CGWindowIDs)
CFArrayRef CGSCopySpacesForWindows(CGSConnectionID connection, CGSSpaceMask mask, CFArrayRef windowIds);

// XXX: Undocumented private API to get the CGSSpaceType for a given space
CGSSpaceType CGSSpaceGetType(CGSConnectionID connection, CGSSpaceID space);

// XXX: Undocumented private API to add the given windows (CGWindowIDs) to the given spaces (CGSSpaceIDs)
void CGSAddWindowsToSpaces(CGSConnectionID connection, CFArrayRef windowIds, CFArrayRef spaceIds);

// XXX: Undocumented private API to remove the given windows (CGWindowIDs) from the given spaces (CGSSpaceIDs)
void CGSRemoveWindowsFromSpaces(CGSConnectionID connection, CFArrayRef windowIds, CFArrayRef spaceIds);
