## This example demonstrates the differences in parsing with blarg and
## std/parseopt. For most things it will function as a drop-in replacement.
## However, std/parseopt does not correctly parse option values that begin with
## `-`, treating them instead as options unless explicitly separated by a `=` or
## `:`. To see this, try running `./ex_parseopt.nim --foo "--bar"`
from os import commandLineParams
from strutils import `%`, escape
from sequtils import mapIt
import parseopt
import blarg

echo "parseopt:"
var p = parseopt.initOptParser(commandLineParams())
for kind, key, val in parseopt.getopt(p):
  echo "  Kind: $1  Key: $2  Value: $3" % mapIt([$kind, key, val], it.escape)

echo ""
echo "blarg:"
var q = blarg.initOptParser(commandLineParams())
for kind, key, val in blarg.getopt(q):
  echo "  Kind: $1  Key: $2  Value: $3" % mapIt([$kind, key, val], it.escape)
