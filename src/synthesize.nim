# import strutils

import kbdtype, tokentype
import parser
import locale

proc post_keyevent(key: cint, pressed: bool) {.importc.}
proc synthesize_key_prep(): void {.importc.}
proc synthesize_text*(text: cstring): void {.importc.}

type
  Keycode = enum
    KCCmd   = 0x37,
    KCShift = 0x38,
    KCAlt   = 0x3A,
    KCCtrl  = 0x3B,
    KCFn    = 0x3F

const modifier_codes = [
 (Alt, KCAlt),
 (Shift, KCShift),
 (Cmd, KCCmd),
 (Ctrl, KCCtrl),
 (Fn, KCFn)
]
# proc postKeyevent(key: int16, pressed: bool) =
#   CGPostKeyboardEvent(0, key, pressed)

proc synthesizeModifiers(kbd: Kbd, pressed: bool): void =
  # post_keyevent(kbd.flags, pressed)
  for modpair in modifier_codes:
    if (ord(modpair[0]) and kbd.flags) != 0:
      let keycode = cint(ord(modpair[1]))
      post_keyevent(keycode, pressed);
    # echo "mod $1 $2" % [ $modpair[0], $(ord(modpair[0]) and kbd.flags) ]

proc synthesize_key*(key: string): void =
  if not initialize_keycode_map(): return

  let parser = makeParser(key.toTokens())

  # NOTE: closing this cause the code to not work
  # close(stdout)
  close(stderr)

  let kbd = parser.parsekbd()

  synthesize_key_prep()

  synthesizeModifiers(kbd, true)
  post_keyevent(kbd.key, true)

  post_keyevent(kbd.key, false)
  synthesizeModifiers(kbd, false)