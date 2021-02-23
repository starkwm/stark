#ifndef extern_h
#define extern_h

AXError _AXUIElementGetWindow(AXUIElementRef element, uint32_t *identifier);

extern int SLSMainConnectionID(void);

extern uint64 SLSGetActiveSpace(int cid);

extern uint64 SLSManagedDisplayGetCurrentSpace(int cid, CFStringRef screen);

extern CFArrayRef SLSCopyManagedDisplaySpaces(int cid);

extern CFArrayRef SLSCopySpacesForWindows(int cid, int mask, CFArrayRef windowIDs);

extern int SLSSpaceGetType(int cid, uint64 sid);

extern void SLSAddWindowsToSpaces(int cid, CFArrayRef windows, CFArrayRef spaces);

extern void SLSRemoveWindowsFromSpaces(int cid, CFArrayRef windows, CFArrayRef spaces);

#endif
