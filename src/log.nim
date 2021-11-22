
import strutils
import Location

template debug*(msg: string) =
  #FIXME: FIX THIS !!!!!!!!!!!
  # when defined(debug):
  stdout.writeLine(msg)

template warn*(msg: string) =
  stdout.writeLine("WARN: " & msg)

proc error*(loc: Location, detail: string): void =
  let sep = "\n" & repeat("-", 79) & "\n"
  let locstr = (if loc != nil: $loc else: "")
  let message = sep & locstr & ", " & detail & sep
  raise newException(ValueError, message)

proc error*(message: string): void =
  error(nil, message)