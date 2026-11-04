#!/bin/bash
# the whole addon in the full harness: run_full.sh <addon folder (…/ClaraComboPoints)> <output name>
cd "$(dirname "$0")"
ulimit -v 4000000
FULLENV="$PWD/fullenv" timeout ${FULL_TIMEOUT:-900} venv/bin/python -u -I fullenv/full_run.py fullenv/full_harness.lua "$1" > "full_out_${2:-run}.txt" 2>&1
echo "exit $?"
