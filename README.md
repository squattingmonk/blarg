# blarg

A basic little argument parser for command-line tools.

Forked from [cligen](https://github.com/c-blake/cligen)'s `parseopt3` module.

## Requirements

- [nim](https://nim-lang.org) >= 1.6.0

## Installation

```console
$ git clone https://github.com/squattingmonk/blarg.git
$ cd blarg
$ nimble install
```

## Usage

In most cases, `blarg` can be used as a drop-in replacement for `std/parseopt`:

```nim
import blarg

for kind, key, val in getopt():
  case kind
  of cmdArgument:
    echo "got argument ", key
  of cmdShortOption, cmdLongOption:
    echo "got option ", key, " = ", val
  else:
    assert false # Cannot happen
```

For detailed usage, see the [docs](https://squattingmonk.github.io/blarg).

## Features

- Separator characters may be required or optional, and may be customized. If
  optional, short or long options that do not expect a value must be specified
  in `shortNoVal` and `longNoVal` respectively.
- Supports operator characters before separators (e.g., `--foo+=bar`)
- Supports `--` and custom stop words, which treat any following options as
  arguments.
- Stop words and long options that do not expect a value can be normalized
  (e.g., normalizing with `strutils.normalize` makes `--foobar` match
  `--fooBar`). The normalizing proc is optional and customizable, unlike
  `cligen/parseopt3`.

## TODO

- Add more examples for advanced usage
