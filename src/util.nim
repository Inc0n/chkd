import options
import strutils
import times

import location

var DEBUG* = false
var VERBOSE* = false
var PROFILE* = false

func assoc*[T, U](alist: openArray[(T, U)], key: T): Option[U] =
  for pair in alist:
    if pair[0] == key:
      return some(pair[1])
  return none(U)

template timethis*(name: string, statements: untyped) =
  let time = cpuTime()
  statements
  if PROFILE:
    let diff = (cpuTime() - time) * 1000.0
    let timespent = diff.formatFloat(ffDecimal, 4)
    echo("$2ms ($1)" % [ name, timespent ])
    
proc debug*(msg: string) =
  if DEBUG or VERBOSE:
    stdout.writeLine(msg)

proc warn*(msg: string) =
  stdout.writeLine(msg)

proc error*(loc: Location, detail: string): void =
  let sep = "\n" & "-".repeat(79) & "\n"
  let locstr = (if loc != nil: $loc else: "")
  let message = sep & detail & sep & locstr
  raise newException(ValueError, message)

proc error*(message: string): void =
  error(nil, message)