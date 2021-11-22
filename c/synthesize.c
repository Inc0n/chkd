#include <Carbon/Carbon.h>

#include "synthesize.h"
/* #include "locale.h" */

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

void post_keyevent(uint32_t key, bool pressed) {
    CGPostKeyboardEvent((CGCharCode)0, (CGKeyCode)key, pressed);
}
 
void synthesize_key_prep() {
    CGSetLocalEventsSuppressionInterval(0.0f);
    CGEnableEventStateCombining(false);
}

void synthesize_text(char *text)
{
    CFStringRef text_ref = CFStringCreateWithCString(NULL, text, kCFStringEncodingUTF8);
    CFIndex text_length = CFStringGetLength(text_ref);

    CGEventRef de = CGEventCreateKeyboardEvent(NULL, 0, true);
    CGEventRef ue = CGEventCreateKeyboardEvent(NULL, 0, false);

    CGEventSetFlags(de, 0);
    CGEventSetFlags(ue, 0);

    UniChar c;
    for (CFIndex i = 0; i < text_length; ++i)
    {
        c = CFStringGetCharacterAtIndex(text_ref, i);
        CGEventKeyboardSetUnicodeString(de, 1, &c);
        CGEventPost(kCGAnnotatedSessionEventTap, de);
        usleep(1000);
        CGEventKeyboardSetUnicodeString(ue, 1, &c);
        CGEventPost(kCGAnnotatedSessionEventTap, ue);
    }

    CFRelease(ue);
    CFRelease(de);
    CFRelease(text_ref);
}

#pragma clang diagnostic pop
