#!/bin/bash
# runs every suite; prints the ones not fully passing
cd "$(dirname "$0")"
for t in test.lua $(ls test[0-9]*.lua | sort -V); do
  r=$(../venv/bin/python -I run.py $PWD ${1:-/home/user/Clara-Combo-Points/ClaraComboPoints} $t 2>&1)
  n=$(echo "$r" | grep -c '  FAIL')
  last=$(echo "$r" | tail -1)
  if [ "$n" != "0" ] || ! echo "$last" | grep -q "^0 failure\|ALL OK"; then echo "$t: $n fails | $(echo "$last" | cut -c1-120)"; fi
done
echo finished
