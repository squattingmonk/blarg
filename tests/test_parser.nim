import std/unittest
from std/strutils import toLowerAscii, split, replace, normalize
from std/sequtils import insert

import blarg

suite "Basic option parsing":
  proc normalizeOption(s: string): string =
    for c in s.toLowerAscii:
      if c notin {'-', '_'}:
        result.add c

  test "Empty command-line yields nothing":
    check:
      getopt().len == 0
      getopt("").len == 0

  test "Empty strings can be args or values":
    check:
      getopt(@[""]) ==
        @[(cmdArgument, "", "")]
      getopt(@["-f", ""]) ==
        @[(cmdShortOption, "f", "")]
      getopt(@["--foo", ""]) ==
        @[(cmdLongOption, "foo", "")]

  test "Negative numbers parsed as args with leading space":
    check:
      getopt(@[" -1", "-1", "-1"]) ==
        @[(cmdArgument, " -1", ""),
          (cmdShortOption, "1", "-1")]

  test "Short option parsing":
    check:
      getopt("-a1 -b:2 -c=42 -d -1 -e") ==
        @[(cmdShortOption, "a", "1"),
          (cmdShortOption, "b", "2"),
          (cmdShortOption, "c", "42"),
          (cmdShortOption, "d", "-1"),
          (cmdShortOption, "e", "") ]

  test "Short no-value options":
    check:
      getopt("-a -b=1 -b:2 -b -ab -c -b", shortNoVal = {'a', 'b'}) ==
        @[(cmdShortOption, "a", ""),
          (cmdShortOption, "b", "1"),
          (cmdShortOption, "b", "2"),
          (cmdShortOption, "b", ""),
          (cmdShortOption, "a", ""),
          (cmdShortOption, "b", ""),
          (cmdShortOption, "c", "-b")]

  test "Long option parsing":
    check:
      getopt("--foo bar --baz=qux --foobar:baz --bar --qux") ==
        @[(cmdLongOption, "foo", "bar"),
          (cmdLongOption, "baz", "qux"),
          (cmdLongOption, "foobar", "baz"),
          (cmdLongOption, "bar", "--qux")]

  test "Long no-value options":
    check:
      getopt("--foo --foo=bar --foo:baz --foobar --foo", longNoVal = @["foo"]) ==
        @[(cmdLongOption, "foo", ""),
          (cmdLongOption, "foo", "bar"),
          (cmdLongOption, "foo", "baz"),
          (cmdLongOption, "foobar", "--foo")]

  test "Long no-value options can be normalized":
    let
      cmd = "--FOO bar --f_o-O bar --Foo=bar --fOO:bar --foobar bar"
    check:
      getopt(cmd, longNoVal = @["foo"], normalizeOption = normalizeOption) ==
        @[(cmdLongOption, "FOO", ""),
          (cmdArgument, "bar", ""),
          (cmdLongOption, "f_o-O", ""),
          (cmdArgument, "bar", ""),
          (cmdLongOption, "Foo", "bar"),
          (cmdLongOption, "fOO", "bar"),
          (cmdLongOption, "foobar", "bar")]
      getopt(cmd, longNoVal = @["foo"], normalizeOption = normalize) ==
        @[(cmdLongOption, "FOO", ""),
          (cmdArgument, "bar", ""),
          (cmdLongOption, "f_o-O", "bar"),
          (cmdLongOption, "Foo", "bar"),
          (cmdLongOption, "fOO", "bar"),
          (cmdLongOption, "foobar", "bar")]

  test "Separator can be required":
    check:
      getopt("--foo --foo=bar --bar=baz --bar baz",
             longNoVal = @["foo"],
             requireSeparator = true) ==
        @[(cmdLongOption, "foo", ""),
          (cmdLongOption, "foo", "bar"),
          (cmdLongOption, "bar", "baz"),
          (cmdError, "bar", ""),
          (cmdArgument, "baz", "")]

      getopt("-a -a=b -b=c -b c",
             shortNoVal = {'a'},
             requireSeparator = true) ==
        @[(cmdShortOption, "a", ""),
          (cmdShortOption, "a", "b"),
          (cmdShortOption, "b", "c"),
          (cmdError, "b", ""),
          (cmdArgument, "c", "")]

  test "Alternate separator characters":
    check:
      getopt("-f/bar --foobar/baz", sepChars = {'/'}) ==
        @[(cmdShortOption, "f", "bar"),
          (cmdLongOption, "foobar", "baz")]

  test "Separator characters can be values":
    check:
      getopt("-a:= -b=: -a = -b : -a== -b:: --foo:= --bar=: --foo== --bar:: --foo = --bar : ") ==
        @[(cmdShortOption, "a", "="),
          (cmdShortOption, "b", ":"),
          (cmdShortOption, "a", "="),
          (cmdShortOption, "b", ":"),
          (cmdShortOption, "a", "="),
          (cmdShortOption, "b", ":"),
          (cmdLongOption, "foo", "="),
          (cmdLongOption, "bar", ":"),
          (cmdLongOption, "foo", "="),
          (cmdLongOption, "bar", ":"),
          (cmdLongOption, "foo", "="),
          (cmdLongOption, "bar", ":")]

  test "Options and values not treated as stop words":
    let cmd = "foo --bar foobar --baz"
    check:
      getopt(cmd, stopWords = @["bar"]) == getopt(cmd)
      getopt(cmd, stopWords = @["foobar"]) == getopt(cmd)

  test "All options after stop words treated as arguments":
    let cmd = "foo --bar foobar --baz"
    check:
      getopt(cmd) ==
        @[(cmdArgument, "foo", ""),
          (cmdLongOption, "bar", "foobar"),
          (cmdLongOption, "baz", "")]
      getopt(cmd, stopWords = @["foo"]) ==
        @[(cmdArgument, "foo", ""),
          (cmdArgument, "--bar", ""),
          (cmdArgument, "foobar", ""),
          (cmdArgument, "--baz", "")]
      getopt(cmd, longNoVal = @["bar"], stopWords = @["foobar"]) ==
        @[(cmdArgument, "foo", ""),
          (cmdLongOption, "bar", ""),
          (cmdArgument, "foobar", ""),
          (cmdArgument, "--baz", "")]

  test "Stop words can be normalized":
    check:
      getopt("fOO --bar", stopWords = @["foo"]) ==
        @[(cmdArgument, "fOO", ""),
          (cmdLongOption, "bar", "")]
      getopt("fOO --bar", stopWords = @["foo"], normalizeStopWord = normalize) ==
        @[(cmdArgument, "fOO", ""),
          (cmdArgument, "--bar", "")]

  test "Naked -- treated as stop word":
    check:
      getopt("-- --foo bar") ==
        @[(cmdArgument, "--foo", ""),
          (cmdArgument,  "bar", "")]

  test "Naked - treated as argument":
    check:
      getopt("-") ==
        @[(cmdArgument, "-", "")]
      getopt("-a -") ==
        @[(cmdShortOption, "a", "-")]

  test "Op characters may precede separator characters":
    proc handlePluralType[T: string | seq[string]](v: var T, val: string, op: string) =
      case op
      of "", "=", ":":
        when T is string:
          v = val
        else:
          v.add(val)
      of "+=", "+:": v.add(val)
      of "^=", "^:": v.insert(val)
      of "-=", "-:":
        when T is string:
          for c in val:
            v = v.replace($c, "")
        else:
          v.delete(find(v, val))
      else: assert false

    var
      p = initOptParser("--foo=b --foo=ab --foo+=c --foo-=b --foo^=d", opChars = {'+', '-', '^'})
      s: string
      q: seq[string]

    for kind, key, val in p.getopt:
      if kind == cmdLongOption and key == "foo":
        handlePluralType(s, val, p.sep)
        handlePluralType(q, val, p.sep)
    check:
      s == "dac"
      q == @["d", "ab", "c"]
