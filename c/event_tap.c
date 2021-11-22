#include "event_tap.h"

static CFMachPortRef handle;
static CFRunLoopSourceRef runloop_source;
static EventTapCallback *_callback;

CGEventRef event_tap_callbackwrapper(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userdata) {
    return _callback(type, event) ? NULL : event;
}

bool event_tap_enabled()
{
    return handle && CGEventTapIsEnabled(handle);
}

bool event_tap_begin(EventTapCallback *callback, CGEventMask mask)
{
    if (event_tap_enabled()) return false;

    _callback = callback;

    handle = CGEventTapCreate(kCGSessionEventTap,
                              kCGHeadInsertEventTap,
                              kCGEventTapOptionDefault,
                              mask,
                              event_tap_callbackwrapper,
                              NULL);

    bool result = event_tap_enabled();
    if (result) {
        runloop_source =
            CFMachPortCreateRunLoopSource(kCFAllocatorDefault,
                                          handle,
                                          0);
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           runloop_source,
                           kCFRunLoopCommonModes);
    }

    return result;
}

void event_tap_reenable() {
    CGEventTapEnable(handle, 1);
}

void event_tap_end()
{
    if (event_tap_enabled()) {
        CGEventTapEnable(handle, false);
        CFMachPortInvalidate(handle);
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runloop_source,
                              kCFRunLoopCommonModes);
        CFRelease(runloop_source);
        CFRelease(handle);
        handle = NULL;
    }
}
