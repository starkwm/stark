@import Carbon;

static OSStatus StarkCarbonEventCallback(__unused EventHandlerCallRef eventHandlerCall, EventRef event, __unused void *context);

EventHandlerUPP StarkCarbonEventCallbackPointer;