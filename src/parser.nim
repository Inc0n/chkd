
import strutils, sequtils, sugar
import options
import tables
import osproc

import util
import kbdtype, tokentype
import config
import locale

# forward declare
proc evalConfig(conf: Config): void

type
  Parser = ref object
    index: int
    # expIndex: int
    tokens: seq[Token]

let tokenEOF* = makeToken(Tok.EOF, "\0")

func makeParser*(tokens: seq[Token]): Parser =
  return Parser(index: 0, tokens: tokens)

func hasTokens(this: Parser): bool =
  this.index < this.tokens.len()

proc currentToken(this: Parser): Token =
  if this.hasTokens(): this.tokens[this.index]
  else: tokenEOF

proc advance(this: Parser): void = this.index += 1
proc advanceToken(this: Parser): Token =
  let tok = this.currentToken()
  this.advance()
  return tok

proc error(this: Parser, detail: string): void =
  let tok = this.currentToken()
  error(tok.loc, "Parsing Error, " & detail)

# proc eat(this: Parser) = this.expIndex = this.index

## parse

proc expectNext(this: Parser, kinds: set[Tok], message: string): Token {.discardable.} =
  let tok = this.advanceToken()
  if (tok.kind in kinds):
    return tok
  this.error(message & tok.text)

proc expectNext(this: Parser, kind: Tok, message: string): Token =
  return this.expectNext({ kind }, message)

# parse

proc parsehexkbd(this: Parser): Kbd =
  let token = this.advanceToken()
  try:
    let keycode = cint(token.text.parseHexInt())
    return makeKbd(keycode)
  except ValueError:
    this.error(token.text & " is not a valid hex number")

proc parseStrKbd(this: Parser, conf: Config, flags: cint = 0): Kbd =
  let tok = this.currentToken()
  if tok.kind == Tok.Modifier:
    this.advance()
    # tok must be of type modifer now
    #DONE <2021-09-16 THU>: convert and add modifier flag to kbd
    let modflag = parse_modifier(tok.text)
    if modflag != 0:
      return this.parseStrKbd(conf, flags or modflag)
    elif conf != nil and (tok.text in conf.env):
      let varflags = conf.env[tok.text].flags
      return this.parseStrKbd(conf, varflags or flags)
    else:
      this.error("unexpected modifier:" & tok.text)
  #DONE <2021-09-16 THU>: Check Dash
  elif tok.kind == Tok.Plus:
    this.advance()
    return this.parseStrKbd(conf, flags)
  else:
    debug(" parsing $1" % [$tok])
    case tok.kind
    of Tok.Key:
      this.advance()
      return makeKbd(keycode_from_char(tok.text[0]), flags)
    of Tok.Literal:
      this.advance()
      return parse_key_literal(tok.text, flags)
    of Tok.Newline, Tok.EOF:
      return makeKbd(0, flags)
    else:
      # debug($tok)
      this.error("invalid kbd syntax")

proc parsekbd*(this: Parser, conf: Config = nil): Kbd =
  let tok = this.currentToken()
  if tok.kind == Tok.KeyHex:
    return this.parsehexkbd()
  else:
    return this.parseStrKbd(conf)

proc parseSet(this: Parser, conf: Config, modename: string): void =
  #DONE <2021-09-16 THU>: Error if modename is not the default global modename
  if globalModename != modename:
    this.error("disallow set inside other modes, " & modename)
  let variable = this.expectNext(Variable, "set wants a variable but got ")
  let val = this.parsekbd(conf)
  conf.env[variable.text] = val

# proc parseUntil(this: Parser, kinds: set[Tok], conf: Config, modename: string) : void =

proc compile(cmd: Token, cmds: seq[Token]): Func =
  # assert(cmds.len != 0)
  case cmd.text:
    of "exec":
      let command = cmds.map(x => x.text).join(" ")
      return (proc (conf: Config): void =
                  debug("exec: " & $command)
                  # assert execCmd("echo $PWD") == -1
                  if execCmd(command) != -1:
                    echo("error exec " & $command))
    of "reload":
      return (proc (conf: Config): void =
                  conf.evalConfig())
    of "mode":
      return (proc (conf: Config): void =
                  conf.setCurrentmode(cmds[1].text))
    else:
      error("unexpected subcmd " & cmds[0].text)

proc getCommandKeyword(this: Parser): Token =
  let subcmd = this.currentToken()
  case subcmd.kind:
    of Keyword:
      this.advance()
      return subcmd
    of Identifier:
      return makeToken(Keyword, "exec")
    else:
      this.error("expecting a subcmd but got: " & $subcmd)
    
proc parseCommand(this: Parser, conf: Config): Func =
  #TODO: enable variables in command parsing?
  # let subcmd =
  #   this.expectNext(Keyword, "expecting command here ")
  let subcmd = this.getCommandKeyword()
  debug(" next tok is " & $subcmd)

  #DONE <2021-09-17 FRI>: check if subcmd is valid
  let maybelen = subcmd_keywords.assoc(subcmd.text)
  if not isSome(maybelen):
    this.error("unknown sub command " & subcmd.text)

  var tokens: seq[Token] = @[]

  while not (this.currentToken().kind in { Newline, EOF }):
    let tok = this.currentToken()
    if not (tok.kind in { Identifier, String, Text }):
      warn("invalid command construct: $1" % [ $tok ])
    # let tok =
    #   this.expectNext(, , $this.tokens[this.index+1]])
    tokens.add(this.advanceToken())

  let len = maybelen.get()
  if (len == -1) or (tokens.len != len):
    return compile(subcmd, tokens)
  else:
    this.error("$1 command expects $2 arguments but got $3" % [
      subcmd.text, $len, $tokens.len
    ])

proc parseBind(this: Parser, conf: Config, modename: string): void =
  let kbd      = this.parsekbd(conf)
  discard this.expectNext(Colon, "Expecting ':' after a kbd")
  let commands = this.parseCommand(conf)
  let mode     = conf.modemap[modename]

  debug("binding key: $1, flags: $2" % [ $kbd.key, $kbd.flags ])
  mode.hotkeymap[kbd] = commands

# forward declare this
proc parseExp(this: Parser, conf: Config, modename: string): void

proc parseBlock(this: Parser, conf: Config, modename: string): void =
  let start = this.advanceToken()
  if start.kind != BeginList:
    this.error("Missing block for mode " & $modename)

  while not (this.currentToken().kind in { EndList, EOF}):
    this.parseExp(conf, modename)

  if not this.hasTokens():
    this.error("Missing '}' for " & $start)
  else:
    this.advance()

proc parseMode(this: Parser, conf: Config, modename: string): void =
  if modename != globalModename:
    this.error("defining mode within mode is disallowed")

  let idToken =
    this.expectNext(Identifier, "mode wants an identifier but got ")
  if idToken.text in conf.modemap:
    this.error("mode name redefined " & idToken.text)

  conf.modemap[idToken.text] = makeMode(idToken.text)
  this.parseBlock(conf, modename)

proc parseExp(this: Parser, conf: Config, modename: string): void =
  let tok = this.currentToken()
  if tok.eofp():
    return
  elif tok.kind in sexpEnds:
    this.advance()
    this.parseExp(conf, modename)
  elif tok.kind == Keyword:
    this.advance()
    debug("doing " & $tok)
    case tok.text:
      of "set":  this.parseSet(conf, modename)
      of "bind": this.parseBind(conf, modename)
      of "mode": this.parseMode(conf, modename)
      else:      this.error("unimplemented keyword " & tok.text)
  elif tok.kind == Comment:
    this.advance()
    this.parseExp(conf, modename)
  else:
    this.error("unexpected token: " & $tok)

proc parse*(this: Parser, conf: Config): void =
  if this.hasTokens():
    this.parseExp(conf, globalModename)
    this.parse(conf)

proc evalConfig(conf: Config): void =
  let chars = readFile(conf.path)
  let tokens = toTokens(chars, conf.path)
  # echo $tokens
  makeParser(tokens).parse(conf)

proc evalConfig*(conf: Config, filepath: string): void =
  conf.path = filepath
  conf.evalConfig()