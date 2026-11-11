#!/usr/bin/env sh
# Build the option-arithmetic binary into a workspace. Run once per machine.
# Usage:  sh optcalc/build.sh /path/to/workspace
# Needs OCaml:  apt install ocaml   |   brew install ocaml
set -e
[ -n "$1" ] || { echo "usage: sh build.sh /path/to/workspace" >&2; exit 2; }
mkdir -p "$1/bin"
out="$(cd "$1" && pwd)/bin/optcalc"
cd "$(dirname "$0")"
# native if possible, else bytecode
ocamlopt -I +unix unix.cmxa optcalc.ml -o "$out" \
  || ocamlc -I +unix unix.cma optcalc.ml -o "$out"
rm -f optcalc.cmi optcalc.cmo optcalc.cmx optcalc.o
echo "built $out"
