import tables

import kbdtype

# cheat here using a variable identifier which ensure no clash
const globalModename*: string = "$default"

# type 

type
  # Func* = proc
  Func* = proc (c: Config): void

  Mode* = ref object
    name: string
    command: string
    capture*: bool
    hotkeymap*: Table[Kbd, Func]

  Config* = ref object
    currentmode: Mode
    path*: string
    env*: Table[string, Kbd]
    modemap*: Table[string, Mode]
    blacklst*: seq[string]

# proc 

func `$`*(this: Func): string = "<Func ...>"

proc makeMode*(name: string): Mode =
  Mode(name: name, command: "", capture: false,
       hotkeymap: initTable[Kbd, Func]())

# proc initConfig(this: Config): void =
#   let modetable: Table[string, Mode] =

proc makeConfig*(): Config =
  let defaultMode: Mode = makeMode(globalModename)
  let this = Config(currentmode: defaultMode,
                    path: "",
                    env: initTable[string, Kbd](),
                    modemap: initTable[string, Mode](),
                    blacklst: @[])
  this.modemap[globalModename] = defaultMode
  return this

proc getCurrentmode*(conf: Config): Mode {.inline.} =
  return conf.currentmode

proc setCurrentmode*(conf: Config, mode: string): void =
  if mode in conf.modemap:
    conf.currentmode = conf.modemap[mode]