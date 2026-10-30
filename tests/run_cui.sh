#!/bin/bash
# runs the ClassicUI harness on a branch folder, memory capped (fails cleanly instead of being killed)
cd "$(dirname "$0")"
ulimit -v 3000000
timeout 600 venv/bin/python -I ui_lea_run.py tools/cui_harness.lua "$PWD/${1:-avec_wt}/ClaraComboPoints" > cui_out_${2:-run}.txt 2>&1
echo "exit $?"
