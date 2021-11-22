import hashes

type
  Modifier* {.size: sizeof(cint), exportc.} = enum
    Alt         = (1 shl  0),
    LAlt        = (1 shl  1),
    RAlt        = (1 shl  2),
    Shift       = (1 shl  3),
    LShift      = (1 shl  4),
    RShift      = (1 shl  5),
    Cmd         = (1 shl  6),
    LCmd        = (1 shl  7),
    RCmd        = (1 shl  8),
    Ctrl        = (1 shl  9),
    LCtrl       = (1 shl 10),
    RCtrl       = (1 shl 11),
    Fn          = (1 shl 12),
    Passthrough = (1 shl 13),
    Activate    = (1 shl 14),
    NX          = (1 shl 15),
    # Hyper       = (Cmd or Alt or Shift or Control),
    # Meh         = (Control or Shift or Alt)
  # Modifiers* = set[Modifier]

  # ModPair* = tuple
  #   name: string
  #   flag: Modifier
type
  Kbd* = object
    key*: cint
    flags*: cint

  CKbd* = Kbd

proc hash*(x: Kbd): Hash =
  ## Piggyback on the already available string hash proc.
  ##
  ## Without this proc nothing works!
  result = float(x.key).hash !& float(x.flags).hash
  result = !$result

func makeKbd*(key: cint = 0, flags: cint = 0): Kbd =
  Kbd(key: key, flags: flags)

func `$`*(this: Kbd): string =
  return "<Kbd key: " & $this.key & " flags: " & $this.flags & ">"

# const ModHyper = { Cmd, Alt, Shift, Ctrl }
# const ModMeh   = { Ctrl, Shift, Alt }

# const modifier_flags* = [
#  ("alt", Alt),     ("lalt", LAlt),     ("ralt", RAlt),
#  ("shift", Shift), ("lshift", LShift), ("rshift", RShift),
#  ("cmd", Cmd),     ("lcmd", LCmd),     ("rcmd", RCmd),
#  ("ctrl", Ctrl),   ("lctrl", LCtrl),   ("rctrl", RCtrl),
#  ("fn", Fn),
# # ("hyper", Hyper),   ("meh", Meh),
# ]

# func findModifier*(modifier: string): Option[Modifier] =
#   return modifier_flags.assoc(modifier)