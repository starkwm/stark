#import "StarkCarbonEvent.h"
#import "Stark-Swift.h"

static OSStatus StarkCarbonEventCallback(__unused EventHandlerCallRef eventHandlerCall, EventRef event, __unused void *context) {
    [HotKey handleEvent:event];
    return noErr;
}

EventHandlerUPP StarkCarbonEventCallbackPointer = StarkCarbonEventCallback;