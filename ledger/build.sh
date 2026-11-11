#!/usr/bin/env sh
# Build the append-only ledger binary into a workspace. Run once per machine.
# Usage:  sh ledger/build.sh /path/to/workspace
# Needs OCaml:  apt install ocaml   |   brew install ocaml
set -e
[ -n "$1" ] || { echo "usage: sh build.sh /path/to/workspace" >&2; exit 2; }
mkdir -p "$1/bin" "$1/decisions"
out="$(cd "$1" && pwd)/bin/ledger"
cd "$(dirname "$0")"
# native if possible, else bytecode
ocamlopt -I +unix unix.cmxa ledger.ml -o "$out" \
  || ocamlc -I +unix unix.cma ledger.ml -o "$out"
rm -f ledger.cmi ledger.cmo ledger.cmx ledger.o
echo "built $out"
