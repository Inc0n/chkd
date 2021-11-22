
#include "locale.h"
#include <Carbon/Carbon.h>

char *copy_cfstring(CFStringRef string)
{
    CFIndex num_bytes = CFStringGetMaximumSizeForEncoding(CFStringGetLength(string), kCFStringEncodingUTF8);
    char *result = malloc(num_bytes + 1);

    // NOTE(koekeishiya): Boolean: typedef -> unsigned char; false = 0, true != 0
    if (!CFStringGetCString(string, result, num_bytes + 1, kCFStringEncodingUTF8)) {
        free(result);
        result = NULL;
    }

    return result;
}

const uint32_t layout_dependent_keycodes[] =
{
    kVK_ANSI_A,            kVK_ANSI_B,           kVK_ANSI_C,
    kVK_ANSI_D,            kVK_ANSI_E,           kVK_ANSI_F,
    kVK_ANSI_G,            kVK_ANSI_H,           kVK_ANSI_I,
    kVK_ANSI_J,            kVK_ANSI_K,           kVK_ANSI_L,
    kVK_ANSI_M,            kVK_ANSI_N,           kVK_ANSI_O,
    kVK_ANSI_P,            kVK_ANSI_Q,           kVK_ANSI_R,
    kVK_ANSI_S,            kVK_ANSI_T,           kVK_ANSI_U,
    kVK_ANSI_V,            kVK_ANSI_W,           kVK_ANSI_X,
    kVK_ANSI_Y,            kVK_ANSI_Z,           kVK_ANSI_0,
    kVK_ANSI_1,            kVK_ANSI_2,           kVK_ANSI_3,
    kVK_ANSI_4,            kVK_ANSI_5,           kVK_ANSI_6,
    kVK_ANSI_7,            kVK_ANSI_8,           kVK_ANSI_9,
    kVK_ANSI_Grave,        kVK_ANSI_Equal,       kVK_ANSI_Minus,
    kVK_ANSI_RightBracket, kVK_ANSI_LeftBracket, kVK_ANSI_Quote,
    kVK_ANSI_Semicolon,    kVK_ANSI_Backslash,   kVK_ANSI_Comma,
    kVK_ANSI_Slash,        kVK_ANSI_Period,      kVK_ISO_Section
};

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wint-to-void-pointer-cast"

static UCKeyboardLayout *keyboard_layout;

bool init_keyboard_layout() {
    TISInputSourceRef keyboard = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
    CFDataRef uchr = (CFDataRef)TISGetInputSourceProperty(keyboard, kTISPropertyUnicodeKeyLayoutData);
    CFRelease(keyboard);

    keyboard_layout = (UCKeyboardLayout *)CFDataGetBytePtr(uchr);
    return keyboard_layout != NULL;
}

char *keyboardlayout_translate(uint32_t keycode)
{
    UniCharCount len;
    UniChar chars[255]; 
    UInt32 state = 0;
    if (keyboard_layout
        && UCKeyTranslate(keyboard_layout,
                          keycode,
                          kUCKeyActionDown,
                          0,
                          LMGetKbdType(),
                          kUCKeyTranslateNoDeadKeysMask,
                          &state,
                          array_count(chars),
                          &len,
                          chars) == noErr
        && len > 0) {
        CFStringRef key_cfstring =
            CFStringCreateWithCharacters(NULL, chars, len);
        char *key_cstring = copy_cfstring(key_cfstring);
        /* printf("%d %s\n", keycode, key_cstring); */
        CFRelease(key_cfstring);
        return key_cstring;
    } else {
        return NULL; 
    }
}

uint32_t get_keyboard_keycodes(int index) {
    if (index < array_count(layout_dependent_keycodes) && index >= 0)
        return layout_dependent_keycodes[index];
    return array_count(layout_dependent_keycodes);
}

#pragma clang diagnostic pop

