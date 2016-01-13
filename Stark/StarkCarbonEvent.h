@import Carbon;

static OSStatus StarkCarbonEventCallback(EventHandlerCallRef _, EventRef event, void *context);

EventHandlerUPP StarkCarbonEventCallbackPointer;
