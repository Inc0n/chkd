
import tables, strutils
import kbdtype
import log

# importc
proc init_keyboard_layout(): bool {.importc.}
proc get_keyboard_keycodes(index: cint): uint32 {.importc.}
proc keyboardlayout_translate(keycode: uint32): cstring {.importc.}

proc parse_key_literal*(key: cstring, flags: cint): CKbd {.importc.}
proc parse_modifier*(modifier: cstring): cint {.importc.}

var keymap = Table[string, uint32]()

proc keycode_from_char*(c: char): cint =
  var str = ""
  str.add(c)
  if str in keymap:
    cast[cint](keymap[str])
  else:
    0

proc initialize_keycode_map*(): bool =
  let length = cast[cint](get_keyboard_keycodes(-1))
  debug("length: " & $length)

  if not init_keyboard_layout():
    return false

  for i in 0..<length:
    let keycode = get_keyboard_keycodes(i)
    let key_str = keyboardlayout_translate(keycode)
    if key_str != cstring(nil):
      let key = $key_str
      # debug("key $2 $1 $3" % [key, $keycode, $i])
      keymap[key] = keycode
  return true


    