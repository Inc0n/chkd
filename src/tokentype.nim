
import strutils, sequtils, sugar
import options, re

import location, util

type
  Tok* = enum
    Identifier,
    Keyword,
    Variable,
    Text,

    Colon,
    Plus, # kbd connector
    Modifier,
    Literal,
    KeyHex,
    Key,

    Comment,
    String,
    BeginList,
    EndList,
    NewLine,
    EOF

  TokenDef* = ref object
    kind*: Tok
    reg*: Regex

  Token* = ref object
    kind*: Tok
    text*: string
    loc*: Location

func makeToken*(kind: Tok, text: string, loc: Location = nil): Token =
  Token(kind: kind, text: text, loc: loc)

func `$`*(this: Token): string =
  "<$1 $2 $3>" % [$this.kind, $this.text, if this.loc == nil: ""
                                          else: $this.loc]

let subcmd_keywords* = @[
  ("exec", -1),
  ("reload", 0),
  ("mode", 1)
]

let keywords_str* = concat(@[
  "set", "bind", "mode",
  # sub command keyword
  "exec", "reload",
], subcmd_keywords.map(x => x[0]))

const literal_keycode_str* = [
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
]

const modifier_flags_str* = [
 "alt",   "lalt",   "ralt",   
 "shift", "lshift", "rshift", 
 "cmd",   "lcmd",   "rcmd",   
 "ctrl",  "lctrl",  "rctrl",  
 "fn"
 # "hyper",   "meh",
]

func eofp*(tok: Token): bool {.inline.} =
  tok.kind == Tok.EOF

const sexpEnds* = {Tok.Newline}

# const keytokens = [Tok.Key, Tok.KeyHex, Tok.Literal, Tok.Modifier]

func reFrom(list: openArray[string]): Regex =
  re("($1)" % list.join("|"))

let tokenDefs* = @[
  TokenDef(kind: BeginList,  reg: re"([\[\{])"),
  TokenDef(kind: EndList,    reg: re"([\]\}])"),
  TokenDef(kind: Comment,    reg: re"([ ]?#.*)(?:$|\n)"),
  TokenDef(kind: Colon,      reg: re"(:)"),
  TokenDef(kind: Plus,       reg: re"(\+)"),
  TokenDef(kind: Newline,    reg: re"(\n)"),
  TokenDef(kind: KeyHex,     reg: re"(0x[0-9a-fA-F]+)"),
  TokenDef(kind: Modifier,   reg: reFrom(modifier_flags_str)),
  TokenDef(kind: Literal,    reg: reFrom(literal_keycode_str)),
  TokenDef(kind: String,     reg: re"""(\"[^\"]*\")"""),
  TokenDef(kind: Keyword,    reg: reFrom(keywords_str)),
  TokenDef(kind: Identifier, reg: re"([a-zA-Z0-9+=!^%*-/`]{2,})"),
  TokenDef(kind: Variable,   reg: re"(\$[a-zA-Z0-9+=!^%*-/`]+)"),
  TokenDef(kind: Key,        reg: re"(.):"),
  TokenDef(kind: Text,       reg: re"([^ \n]+)"),
]

proc toTokens*(inputs: string, filepath: string = ""): seq[Token] =
  var tokens: seq[Token] = @[]
  let loc = makeLocation(0, 0, filepath)

  proc matchToken(str: string): Option[Token] =
    var matches: array[1, string]
    for def in tokenDefs:
      # we use find bounds as some regex may want to match without capture
      # let (start, finish) = str.findBounds(def.reg, matches, pos)
      # if start != finish and start == 0 and matches.len > 1:
        # pos += finish - start + 1
      if str.match(def.reg, matches, loc.col):
        loc.col += matches[0].len
        # echo (pos, start, finish)
        return some(Token(kind: def.kind, text: matches[0], loc: loc.copy()))
    return none(Token)

  while loc.col < inputs.len:
    case inputs[loc.col]
    of ' ':
      loc.col += 1
      continue
    of '\n':
      loc.col = 0
      loc.line += 1
    else: discard

    let token = inputs.matchToken()
    if token.isSome():
      tokens.add(token.get())
    else:
      error(loc.copy(), "invalid syntax")

  return tokens
