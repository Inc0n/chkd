#ifndef SKHD_EVENT_TAP_H
#define SKHD_EVENT_TAP_H

#include <stdbool.h>
#include <Carbon/Carbon.h>

/* #define EVENT_TAP_CALLBACK(name)           \ */
/*     CGEventRef name(CGEventTapProxy proxy, \ */
/*                     CGEventType type, \ */
/*                     CGEventRef event, \ */
/*                     void *reference) */
#define EVENT_TAP_CALLBACK(name)           \
    bool name(CGEventType type, CGEventRef event)

typedef EVENT_TAP_CALLBACK(EventTapCallback);

/* CGEventRef exampleCallback(CGEventTapProxy proxy, */
/*                            CGEventType type, */
/*                            CGEventRef event, */
/*                            void *reference); */

bool event_tap_enabled();
bool event_tap_begin(EventTapCallback *callback, CGEventMask mask);
void event_tap_reenable();
void event_tap_end();

#define OBSERVE_MASK (1 << kCGEventKeyDown) | (1 << kCGEventFlagsChanged)
#define NORMAL_MASK  (1 << kCGEventKeyDown) | (1 << NX_SYSDEFINED)

#endif
