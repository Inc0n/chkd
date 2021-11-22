#include "hotkey.h"
#include "locale.h"

#define HOTKEY_PASSTHROUGH(a)  ((a) << 2)

#define LRMOD_ALT   0
#define LRMOD_CMD   6
#define LRMOD_CTRL  9
#define LRMOD_SHIFT 3
#define LMOD_OFFS   1
#define RMOD_OFFS   2

static uint32_t cgevent_lrmod_flag[] =
{
    Event_Mask_Alt,     Event_Mask_LAlt,     Event_Mask_RAlt,
    Event_Mask_Shift,   Event_Mask_LShift,   Event_Mask_RShift,
    Event_Mask_Cmd,     Event_Mask_LCmd,     Event_Mask_RCmd,
    Event_Mask_Control, Event_Mask_LControl, Event_Mask_RControl,
};

static uint32_t hotkey_lrmod_flag[] =
{
    Hotkey_Flag_Alt,     Hotkey_Flag_LAlt,     Hotkey_Flag_RAlt,
    Hotkey_Flag_Shift,   Hotkey_Flag_LShift,   Hotkey_Flag_RShift,
    Hotkey_Flag_Cmd,     Hotkey_Flag_LCmd,     Hotkey_Flag_RCmd,
    Hotkey_Flag_Control, Hotkey_Flag_LControl, Hotkey_Flag_RControl,
};

static inline void
passthrough(struct Kbd *hotkey, uint32_t *capture)
{
    *capture |= HOTKEY_PASSTHROUGH((int)has_flags(hotkey, Hotkey_Flag_Passthrough));
}

static void
cgevent_lrmod_flag_to_hotkey_lrmod_flag(CGEventFlags eventflags, uint32_t *flags, int mod)
{
    enum osx_event_mask mask  = cgevent_lrmod_flag[mod];
    enum osx_event_mask lmask = cgevent_lrmod_flag[mod + LMOD_OFFS];
    enum osx_event_mask rmask = cgevent_lrmod_flag[mod + RMOD_OFFS];

    if ((eventflags & mask) == mask) {
        /* bool left  = (eventflags & lmask) == lmask; */
        /* bool right = (eventflags & rmask) == rmask; */

        /* let modifier evalutate to the same left key value */
        /* this saves us from extra computation readjustment */
        /* if (left)        *flags |= hotkey_lrmod_flag[mod + LMOD_OFFS]; */
        /* if (right)       *flags |= hotkey_lrmod_flag[mod + RMOD_OFFS]; */
        /* if (!left && !right) */
        *flags |= hotkey_lrmod_flag[mod];
    }
}

static uint32_t
cgevent_flags_to_hotkey_flags(uint32_t eventflags)
{
    uint32_t flags = 0;

    cgevent_lrmod_flag_to_hotkey_lrmod_flag(eventflags, &flags, LRMOD_ALT);
    cgevent_lrmod_flag_to_hotkey_lrmod_flag(eventflags, &flags, LRMOD_CMD);
    cgevent_lrmod_flag_to_hotkey_lrmod_flag(eventflags, &flags, LRMOD_CTRL);
    cgevent_lrmod_flag_to_hotkey_lrmod_flag(eventflags, &flags, LRMOD_SHIFT);

    if ((eventflags & Event_Mask_Fn) == Event_Mask_Fn) {
        flags |= Hotkey_Flag_Fn;
    }

    return flags;
}

struct Kbd create_eventkey(CGEventRef event)
{
    struct Kbd eventkey = {
        .key = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode),
        .flags = cgevent_flags_to_hotkey_flags(CGEventGetFlags(event))
    };
    return eventkey;
}

bool intercept_systemkey(CGEventRef event, struct Kbd _eventkey)
{
    struct Kbd *eventkey = &_eventkey;
    CFDataRef event_data = CGEventCreateData(kCFAllocatorDefault, event);
    const uint8_t *data  = CFDataGetBytePtr(event_data);
    uint8_t key_code  = data[129];
    uint8_t key_state = data[130];
    uint8_t key_stype = data[123];
    CFRelease(event_data);

    bool result = ((key_state == NX_KEYDOWN) &&
                   (key_stype == NX_SUBTYPE_AUX_CONTROL_BUTTONS));

    if (result) {
        eventkey->key = key_code;
        eventkey->flags = cgevent_flags_to_hotkey_flags(CGEventGetFlags(event)) | Hotkey_Flag_NX;
    }

    return result;
}

/* uint32_t parse_key_hex(struct parser *parser) */
/* { */
/*     struct token key = parser_previous(parser); */
/*     char *hex = copy_string_count(key.text, key.length); */
/*     uint32_t keycode = keycode_from_hex(hex); */
/*     free(hex); */
/*     debug("\tkey: '%.*s' (0x%02x)\n", key.length, key.text, keycode); */
/*     return keycode; */
/* } */

#define KEY_HAS_IMPLICIT_FN_MOD  4
#define KEY_HAS_IMPLICIT_NX_MOD  35

static const char *literal_keycode_str[] =
{
    "return",          "tab",             "space",
    "backspace",       "escape",          "delete",
    "home",            "end",             "pageup",
    "pagedown",        "insert",          "left",
    "right",           "up",              "down",
    "f1",              "f2",              "f3",
    "f4",              "f5",              "f6",
    "f7",              "f8",              "f9",
    "f10",             "f11",             "f12",
    "f13",             "f14",             "f15",
    "f16",             "f17",             "f18",
    "f19",             "f20",

    "sound_up",        "sound_down",      "mute",
    "play",            "previous",        "next",
    "rewind",          "fast",            "brightness_up",
    "brightness_down", "illumination_up", "illumination_down"
};

static uint32_t literal_keycode_value[] =
{
    kVK_Return,     kVK_Tab,           kVK_Space,
    kVK_Delete,     kVK_Escape,        kVK_ForwardDelete,
    kVK_Home,       kVK_End,           kVK_PageUp,
    kVK_PageDown,   kVK_Help,          kVK_LeftArrow,
    kVK_RightArrow, kVK_UpArrow,       kVK_DownArrow,
    kVK_F1,         kVK_F2,            kVK_F3,
    kVK_F4,         kVK_F5,            kVK_F6,
    kVK_F7,         kVK_F8,            kVK_F9,
    kVK_F10,        kVK_F11,           kVK_F12,
    kVK_F13,        kVK_F14,           kVK_F15,
    kVK_F16,        kVK_F17,           kVK_F18,
    kVK_F19,        kVK_F20,

    NX_KEYTYPE_SOUND_UP, NX_KEYTYPE_SOUND_DOWN, NX_KEYTYPE_MUTE,
    NX_KEYTYPE_PLAY, NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_NEXT,          
    NX_KEYTYPE_REWIND, NX_KEYTYPE_FAST, NX_KEYTYPE_BRIGHTNESS_UP, 
    NX_KEYTYPE_BRIGHTNESS_DOWN, NX_KEYTYPE_ILLUMINATION_UP, NX_KEYTYPE_ILLUMINATION_DOWN
};

static inline void
handle_implicit_literal_flags(struct Kbd *hotkey, int literal_index)
{
    if ((literal_index > KEY_HAS_IMPLICIT_FN_MOD) &&
        (literal_index < KEY_HAS_IMPLICIT_NX_MOD)) {
        hotkey->flags |= Hotkey_Flag_Fn;
    } else if (literal_index >= KEY_HAS_IMPLICIT_NX_MOD) {
        hotkey->flags |= Hotkey_Flag_NX;
    }
}

struct Kbd parse_key_literal(char *key, uint32_t flags)
{
    struct Kbd hotkey = {.flags = flags};
    for (int i = 0; i < array_count(literal_keycode_str); ++i) {
        if (strcmp(key, literal_keycode_str[i]) == 0) {
            /* TODO: Add support for implicit literal  */
            handle_implicit_literal_flags(&hotkey, i);
            hotkey.key = literal_keycode_value[i];
            break;
        }
    }
    return hotkey;
}

static enum hotkey_flag modifier_flags_value[] =
{
    /* redirect all modifers to the same key */
    Hotkey_Flag_Alt, Hotkey_Flag_Alt, Hotkey_Flag_Alt,
    /* Hotkey_Flag_LAlt,       Hotkey_Flag_RAlt, */
    Hotkey_Flag_Shift, Hotkey_Flag_Shift, Hotkey_Flag_Shift,
    /* Hotkey_Flag_LShift,     Hotkey_Flag_RShift, */
    Hotkey_Flag_Cmd,
    /* Hotkey_Flag_Cmd, Hotkey_Flag_Cmd, */
    Hotkey_Flag_LCmd,       Hotkey_Flag_RCmd,
    Hotkey_Flag_Control, Hotkey_Flag_Control, Hotkey_Flag_Control,
    /* Hotkey_Flag_LControl,   Hotkey_Flag_RControl, */
    Hotkey_Flag_Fn,         Hotkey_Flag_Hyper,      Hotkey_Flag_Meh,
};

static const char *modifier_flags_str[] =
{
    "alt",   "lalt",    "ralt",
    "shift", "lshift",  "rshift",
    "cmd",   "lcmd",    "rcmd",
    "ctrl",  "lctrl",   "rctrl",
    "fn",    "hyper",   "meh",
};

uint32_t parse_modifier(char *modifier)
{
    for (int i = 0; i < array_count(modifier_flags_str); ++i) {
        if (strcmp(modifier, modifier_flags_str[i]) == 0) {
            return modifier_flags_value[i];
        }
    }
    return 0;
}
