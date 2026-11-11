#!/bin/bash
# runs the whole suite on a ClaraComboPoints folder, prints only what differs from its baseline (file $2)
cd "$(dirname "$0")"
out=$(bash runall.sh "$1" 2>&1 | grep -v "^finished")
if [ -f "$2" ]; then diff <(echo "$out") "$2" | sed 's/^</NOW /; s/^>/WAS /' | grep -v "^---\|^[0-9]"; echo "compared"; else echo "$out" > "$2"; echo "baseline written"; fi
