## This module implements a command-line parser. It has been forked from
## cligen/parseopt3.
from std/os import commandLineParams, quoteShellCommand, parseCmdLine
from std/strutils import find, startsWith, `%`
from std/sequtils import map
from std/sugar import `->`, `=>`

type
  CmdLineKind* = enum ## The detected command-line token
    cmdEnd         ## end of parameters reached
    cmdArgument    ## non-option argument
    cmdLongOption  ## long option (`--option`)
    cmdShortOption ## short option (`-o`)
    cmdError       ## error encountered during parsing

  OptParser* = object of RootObj
    cmd*: seq[string]       ## command line being parsed
    pos*: int               ## current command parameter to inspect
    offset*: int            ## current offset in cmd[pos] for short key block
    optsDone*: bool         ## `--` or a stop word has been seen
    shortNoVal*: set[char]  ## short options not requiring values
    longNoVal*: seq[string] ## long options not requiring values
    sepChars*: set[char]    ## all chars that can be valid separators
    requireSep*: bool       ## whether =|: required between key and value
    opChars*: set[char]     ## all chars that can prefix a sepChar
    stopWords*: seq[string] ## special literal parameters acting like `--`
    sep*: string            ## actual string separating key and value
    kind*: CmdLineKind      ## the detected command-line token
    message*: string        ## a message to display on cmdError
    key*: string            ## the argument or option name
    val*: string            ## the value of an option (blank if noVal opt)
    normalizeOption*: (string) -> string    ## normalizes long opts before comparing to longNoVal
    normalizeStopWord*: (string) -> string  ## normalizes stop words before comparing to stopWords

proc initOptParser*[T: string | seq[string]](
                  cmdline: T = commandLineParams(),
                  shortNoVal: set[char] = {},
                  longNoVal: seq[string] = @[],
                  requireSeparator: bool = false,
                  sepChars: set[char] = {'=', ':'},
                  opChars: set[char] = {},
                  stopWords: seq[string] = @[],
                  normalizeOption: (string) -> string = (s: string) => s,
                  normalizeStopWord: (string) -> string = (s: string) => s): OptParser =
  ## Initializes a command-line parser. `cmdline` should not include the program
  ## name (parameter 0). If `cmdline` is not given, will default to the current
  ## program parameters. If cmdline is a string, it will be split using
  ## `os.parseCmdLine`.
  ##
  ## `shortNoVal` and `longNoVal` respectively specify short- and long-option
  ## keys that do not expect a value.
  ##
  ## If `requireSeparator` is true, option keys and values must be separated by
  ## one of the characters in `sepChars` (e.g., ``--key=value``). If false, the
  ## parser understands that only non-noVal arguments will expect args and users
  ## may say ``-aboVal`` or ``-o Val`` or ``--option Val`` (as well as the
  ## ``-o=Val`` or ``--option=Val`` syntax, which always works).
  ##
  ## If `opChars` is not empty, then any of those characters that occur before
  ## the separator character will be included in the parser's ``.sep`` field.
  ## This allows "incremental" syntax such as ``--option+=val``.
  ##
  ## `stopWords` are arguments that when seen cause all remaining parameters to
  ## be treated as arguments even if they look like options. This is useful for
  ## programs with subcommands (e.g., git); it allows you to fully process the
  ## command line and reprocess its tail. ``--`` functions as a built-in
  ## stopWord. It differs from those in `stopWords` in that it is not itself
  ## returned as an argument.
  ##
  ## `normalizeOption` and `normalizeStopWord` are procs that alter words before
  ## comparing them to `longNoVal` or `stopWords`, respectively. For example,
  ## passing `strutils.normalize` will allow the matching of ``--myOption`` with
  ## ``--my_option``. The default behavior is to match verbatim.
  result.cmd =
    when T is string:
      if cmdline == "": commandLineParams()
      else: cmdline.parseCmdLine()
    else:
      cmdline
  result.shortNoVal = shortNoVal
  result.longNoVal = longNoVal.map(normalizeOption)
  result.stopWords = stopWords.map(normalizeStopWord)
  result.normalizeOption = normalizeOption
  result.normalizeStopWord = normalizeStopWord
  result.requireSep = requireSeparator
  result.sepChars = sepChars
  result.opChars = opChars
  result.offset = 0
  result.pos = 0

proc doShort(p: var OptParser) =
  proc cur(p: OptParser): char =
    if p.offset < p.cmd[p.pos].len:
      p.cmd[p.pos][p.offset]
    else: '\0'

  p.kind = cmdShortOption
  p.val = ""
  p.key = $p.cur
  p.offset += 1

  # Handle -k=value or -k+=value
  if p.cur in p.opChars or p.cur in p.sepChars:
    let mark = p.offset
    while p.cur != '\0' and p.cur notin p.sepChars and p.cur in p.opChars:
      p.offset += 1
    if p.cur in p.sepChars:
      p.sep = p.cmd[p.pos][mark..p.offset]
      p.val = p.cmd[p.pos][p.offset+1..^1]
      p.offset = 0
      p.pos += 1
      return
    else:
      p.offset = mark

  # Handle -k
  if p.key[0] in p.shortNoVal:
    if p.offset == p.cmd[p.pos].len:
      p.offset = 0
      p.pos += 1
    return

  if p.requireSep:
    p.message = "Expected value after -" & p.key
    p.kind = cmdError
    if p.cmd[p.pos].len - p.offset == 0:
      p.offset = 0
      p.pos += 1
    return

  # Handle -kvalue
  if p.cmd[p.pos].len - p.offset > 0:
    p.val = p.cmd[p.pos][p.offset..^1]
    p.offset = 0
    p.pos += 1
    return

  # Handle -k value
  if p.pos < p.cmd.len - 1:
    p.val = p.cmd[p.pos + 1]
    p.offset = 0
    p.pos += 2
    return

  # No value listed for option
  p.val = ""
  p.offset = 0
  p.pos += 1

proc doLong(p: var OptParser) =
  p.kind = cmdLongOption
  p.val = ""
  let param = p.cmd[p.pos]
  p.pos += 1

  # Handle --key=value or --key+=value
  let sep = find(param, p.sepChars)
  if sep > 2:
    var op = sep
    while op > 2 and param[op - 1] in p.opChars:
      op -= 1
    p.key = param[2..(op - 1)]
    p.sep = param[op..sep]
    p.val = param[(sep + 1)..^1]
    return

  # Handle --key
  p.key = param[2..^1]
  if p.normalizeOption(p.key) in p.longNoVal:
    return

  if p.requireSep:
    p.kind = cmdError
    p.message = "Expected value after --" & p.key
    return

  # Handle --key value
  if p.pos < p.cmd.len:
    p.val = p.cmd[p.pos]
    p.pos += 1
  elif p.longNoVal.len != 0:
    p.val = ""
    p.pos += 1

proc next*(p: var OptParser) =
  ## Advances the parser to the next token. `p.kind` specifies the kind of
  ## token that has been parsed; `p.key` and `p.val` are set accordingly.
  p.sep = ""

  # 1: Handle remaining short opts
  if p.offset > 0:
    doShort(p)
    return

  # 2: Check if there are any params left
  if p.pos >= p.cmd.len:
    p.kind = cmdEnd
    return

  # 3: Handle non-option params
  if not p.cmd[p.pos].startsWith("-") or p.optsDone:
    p.kind = cmdArgument
    p.key = p.cmd[p.pos]
    p.val = ""

    # Check for stop words. Should only hit step 3 after this.
    if p.normalizeStopWord(p.key) in p.stopWords:
      p.optsDone = true
    p.pos += 1
    return

  # 4: Handle `--`, which counts as a built-in stop word
  if p.cmd[p.pos] == "--":
    p.optsDone = true
    p.pos += 1
    next(p) # Skip the -- itself
    return

  # 5: Handle long opts
  if p.cmd[p.pos].startsWith("--"):
    doLong(p)

  # 6: Handle short opts
  else:
    # 6a: Handle `-` (often used to indicate stdin)
    if p.cmd[p.pos].len == 1:
      p.kind = cmdArgument
      p.key = p.cmd[p.pos]
      p.val = ""
      p.pos += 1
    else:
      p.offset = 1  # Skip initial `-`
      doShort(p)

type
  GetOptResult* = tuple[kind: CmdLineKind, key, val: string]

iterator getopt*(p: var OptParser, reset = false): GetOptResult =
  ## Convenience iterator for iterating over the given OptParser. Will continue
  ## parsing where previous parsing had left off unless `reset` is true.
  if reset:
    p.pos = 0
  while true:
    next(p)
    if p.kind == cmdEnd: break
    yield (p.kind, p.key, p.val)

iterator getopt*[T: string | seq[string]](
                cmdline: T = commandLineParams(),
                shortNoVal: set[char] = {},
                longNoVal: seq[string] = @[],
                requireSeparator: bool = false,
                sepChars: set[char] = {'=', ':'},
                opChars: set[char] = {},
                stopWords: seq[string] = @[],
                normalizeOption: (string) -> string = (s: string) => s,
                normalizeStopWord: (string) -> string = (s:string) => s): GetOptResult =
  ## Convenience operator that initializes an OptParser and iterates over it.
  var p = initOptParser(cmdline, shortNoVal, longNoVal, requireSeparator,
                        sepChars, opChars, stopWords, normalizeOption, normalizeStopWord)
  while true:
    next(p)
    if p.kind == cmdEnd: break
    yield (p.kind, p.key, p.val)

proc getopt*[T: string | seq[string]](
            cmdline: T = commandLineParams(),
            shortNoVal: set[char] = {},
            longNoVal: seq[string] = @[],
            requireSeparator: bool = false,
            sepChars: set[char] = {'=', ':'},
            opChars: set[char] = {},
            stopWords: seq[string] = @[],
            normalizeOption: (string) -> string = (s: string) => s,
            normalizeStopWord: (string) -> string = (s:string) => s): seq[GetOptResult] =
  ## As the `getopt` iterator, but returns a sequence.
  for kind, key, val in getopt(cmdline, shortNoVal, longNoVal, requireSeparator,
                               sepChars, opChars, stopWords, normalizeOption, normalizeStopWord):
    result.add (kind, key, val)

proc remainingArgs*(p: OptParser): seq[string] =
  ## Returns a sequence of the args that have not yet been parsed.
  result = if p.pos < p.cmd.len: p.cmd[p.pos..^1] else: @[]

proc cmdLineRest*(p: OptParser): string =
  ## Returns a string of the args that have not yet been parsed.
  result = p.remainingArgs.quoteShellCommand
