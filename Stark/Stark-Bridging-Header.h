@import Foundation;

typedef int CGSConnectionID;

typedef size_t CGSSpaceID;

typedef enum {
    /// User-created desktop spaces.
    CGSSpaceTypeUser       = 0,
    /// Fullscreen spaces.
    CGSSpaceTypeFullscreen = 4,
    /// System spaces e.g. Dashboard.
    CGSSpaceTypeSystem     = 2,
} CGSSpaceType;

typedef enum {
    CGSSpaceIncludesCurrent = 1 << 0,
    CGSSpaceIncludesOthers  = 1 << 1,
    CGSSpaceIncludesUser    = 1 << 2,

    CGSSpaceVisible         = 1 << 16,

    kCGSCurrentSpaceMask = CGSSpaceIncludesUser | CGSSpaceIncludesCurrent,
    kCGSOtherSpacesMask = CGSSpaceIncludesOthers | CGSSpaceIncludesCurrent,
    kCGSAllSpacesMask = CGSSpaceIncludesUser | CGSSpaceIncludesOthers | CGSSpaceIncludesCurrent,
    KCGSAllVisibleSpacesMask = CGSSpaceVisible | kCGSAllSpacesMask,
} CGSSpaceMask;

/// Gets the default connection for this process.
CG_EXTERN CGSConnectionID CGSMainConnectionID(void);

/// Gets the ID of the space currently visible to the user.
CG_EXTERN CGSSpaceID CGSGetActiveSpace(CGSConnectionID cid);

/// Get the ID of the space for a given screen.
CG_EXTERN CGSSpaceID CGSManagedDisplayGetCurrentSpace(CGSConnectionID cid, CFStringRef screen);

/// Returns an array of dictionaries describing the spaces each screen contains.
CG_EXTERN CFArrayRef CGSCopyManagedDisplaySpaces(CGSConnectionID cid);

/// Given an array of window numbers, returns the IDs of the spaces those windows lie on.
CG_EXTERN CFArrayRef CGSCopySpacesForWindows(CGSConnectionID cid, CGSSpaceMask mask, CFArrayRef windowIDs);

/// Gets the type of a space.
CG_EXTERN CGSSpaceType CGSSpaceGetType(CGSConnectionID connection, CGSSpaceID space);

/// Given an array of window numbers and an array of space IDs, adds each window to each space.
CG_EXTERN void CGSAddWindowsToSpaces(CGSConnectionID cid, CFArrayRef windows, CFArrayRef spaces);

/// Given an array of window numbers and an array of space IDs, removes each window from each space.
CG_EXTERN void CGSRemoveWindowsFromSpaces(CGSConnectionID cid, CFArrayRef windows, CFArrayRef spaces);

/// Get the ID of a window for the given accessibility element.
AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *identifier);
