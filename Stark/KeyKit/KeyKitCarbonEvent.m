#import "KeyKitCarbonEvent.h"
#import "Stark-Swift.h"

static OSStatus KeyKitCarbonEventCallback(EventHandlerCallRef _, EventRef event, void *context) {
    [[KeyKit sharedInstance] handleCarbonEvent:event];
    return noErr;
}

EventHandlerUPP KeyKitCarbonEventCallbackPointer = KeyKitCarbonEventCallback;