#import "StarkCarbonEvent.h"
#import "Stark-Swift.h"

static OSStatus StarkCarbonEventCallback(EventHandlerCallRef _, EventRef event, void *context) {
    [[KeyKit sharedInstance] handleCarbonEvent:event];
    return noErr;
}

EventHandlerUPP StarkCarbonEventCallbackPointer = StarkCarbonEventCallback;