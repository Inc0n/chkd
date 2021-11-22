
import posix, posix_utils, parseopt, strutils, os
import tables

import kbdtype, parser, synthesize, config
import util, locale

const VERSION = "0.0.1"

## c imports

type
  CGEventType {.size: sizeof(cint).} = enum
    kCGEventKeyDown = 10,
    kCGEventKeyUp = 11,
    kCGEventFlagsChanged = 12,
    NX_SYSDEFINED = 14,
    kCGEventTapDisabledByTimeout = 0xFFFFFFFE,
    kCGEventTapDisabledByUserInput = 0xFFFFFFFF
  CGEvent = object
  CGEventRef = ptr CGEvent
  EventTapCallback =
          proc (eventtype: CGEventType; event: CGEventRef): CGEventRef {.cdecl.}
  SignalCallback = proc (signal: cint): void {.cdecl.}
              

const kVK_ANSI_C = 0x08

const NORMAL_MASK = (1 shl ord(kCGEventKeyDown)) or (1 shl ord(NX_SYSDEFINED))
const OBSERVE_MASK = (1 shl ord(kCGEventKeyDown)) or (1 shl ord(kCGEventFlagsChanged))

# proc event_tap_enabled(): bool {.importc.}
proc event_tap_begin(callback: EventTapCallback, mask: cint): bool {.importc.}
proc event_tap_reenable(): void  {.importc.}

proc signalSetup(callback: SignalCallback): void {.importc.}

proc create_eventkey(event: ptr): CKbd {.importc.}
proc intercept_systemkey(event: ptr, kbd: CKbd): bool {.importc.}
proc check_privileges(): bool {.importc.}
proc carbon_event_init(): bool {.importc.}
proc carbon_process_name(): cstring {.importc.}
proc main_setup(): void  {.importc.}
proc startRunloop(): void  {.importc.}

proc read_pid_file(): Pid {.importc.}
proc create_pid_file(): void {.importc.}

## type 

type
  Option = ref object
    configpath: string
    verbose: bool
    profile: bool
    hotload: bool

proc makeOption(): Option =
  Option(verbose: false, profile: false, hotload: false, configpath: "")

## global variables

let option = makeOption()
let conf = makeConfig()

## proc

proc getConfig(filename: string): string =
  var configpath: string
  var home = os.getEnv("HOME", "")

  if home != "":
    configpath = "$1/.config/skhd/$2" % [ home, $filename ]
  else:
    home = os.getEnv("XDG_CONFIG_HOME", "")
    if home != "":
      configpath = "$1/skhd/$2" % [ home, $filename ]

  return configpath

proc keyObserverHandler(eventtype: CGEventType, event: CGEventRef): CGEventRef {.exportc, cdecl.} =
  case eventtype:
    of kCGEventTapDisabledByTimeout, kCGEventTapDisabledByUserInput:
      debug("skhd: restarting event-tap\n")
      event_tap_reenable()
    of kCGEventKeyDown, kCGEventFlagsChanged:
      let kbd = create_eventkey(event);
      let keycode = kbd.key
      let flags = cast[int](kbd.flags)
      if (keycode == kVK_ANSI_C) and ((flags and 0x40000) != 0):
        # allow program to quit if C-c is pressed
        quit(1)
      stdout.writeLine("\rkeycode: 0x$1\tflags: $2" % [
        keycode.toHex(),
        $flags
        # .toBin(16)
      ])
      flushFile(stdout)
      return nil
    else:
        discard
  return event

proc signalCallback(signal: cint): void {.cdecl.} =
  debug("ckhd: SIGUSR1 received.. reloading config")
  conf.evalConfig(option.configpath)

proc findAndExec(kbd: CKbd): bool =
  let mode = conf.getCurrentmode()
  timethis("findAndExec"):
    let map = mode.hotkeymap
    # echo ("key: $1, flags: $2" % [ $kbd.key, $kbd.flags ])
    if kbd in map:
      debug("command found")
      let command = map[kbd]
      command(conf)
  return mode.capture

proc keyHandler(eventtype: CGEventType, event: ptr object): ptr {.exportc, cdecl.} =
  case eventtype:
    of kCGEventTapDisabledByTimeout, kCGEventTapDisabledByUserInput:
      debug("skhd: restarting event-tap\n")
      event_tap_reenable()
    of kCGEventKeyDown:
      if $carbon_process_name() in conf.blacklst or
         findAndExec(create_eventkey(event)):
        return nil
    of NX_SYSDEFINED:
      if $carbon_process_name() in conf.blacklst:
        return nil
      let kbd = create_eventkey(event);
      if intercept_systemkey(event, kbd):
        if findAndExec(kbd):
          return nil;
    else: discard

  return event

proc writeVersion(): void =
  echo("ckhd version " & $VERSION)
  quit()

# commandLineParams(
proc parseArgs(self: Option): void =
  # echo $getopt(args)
  # echo "Hello??? ", $args
  for kind, key, val in getopt():
    case kind
    of cmdArgument: discard
      # filename = key
    of cmdLongOption, cmdShortOption:
      case key
      # of "help", "h": writeHelp()
      of "version": writeVersion()
      of "verbose", "v": VERBOSE = true
      of "profile", "p": PROFILE = true
      of "hotload":  self.hotload = true
      of "key", "k":  synthesize_key(val); quit()
      of "text", "t":  synthesize_text(val); quit()
      of "config", "c": self.configpath = val
      of "observe", "o":
        echo("observing, start pressing the hotkeys...")
        if not event_tap_begin(keyObserverHandler, OBSERVE_MASK):
          echo("Event tap cannot begin")
        startRunloop()
      of "reload", "r":
        let pid = read_pid_file()
        if pid != 0:
          debug("sent reload signal")
          sendSignal(pid, SIGUSR1)
        else:
          debug("reload signal cannot be sent")
        quit()
      else:
        echo("ignored flags, $1" % [$key])
    of cmdEnd:
      assert(false) # cannot happen

when isMainModule:
  if (getuid() == 0 or geteuid() == 0):
    error("ckhd: running as root is not allowed! abort..\n")

  timethis("init"):
    option.parseArgs()
    create_pid_file()

    if not check_privileges():
      error("ckhd: must be run with accessibility access! abort..\n")

    if not initialize_keycode_map():
      error("ckhd: could not initialize keycode map! abort..\n")

    if not carbon_event_init():
      error("ckhd: could not initialize carbon events! abort..\n")

    if option.configpath == "":
      option.configpath = getConfig("ckhdrc")

    if not fileExists(option.configpath):
      debug("ckhd: config '$1' doesn't exist\n" % option.configpath)

  timethis("config"):
    echo("Loading config.")
    conf.evalConfig(option.configpath)
    echo("Config loaded.")

  if not event_tap_begin(keyHandler, NORMAL_MASK):
    echo("Event tap key handler cannot begin")

  timethis("setup"):
    main_setup()
    signalSetup(signalCallback)
  startRunloop() # NSApplicationLoad()
