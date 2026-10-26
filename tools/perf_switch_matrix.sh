#!/usr/bin/env sh
# Run the mod-facing checks once with every performance switch on, then once
# per switch with only that one off, then once with all of them off.  A mod
# must see the same thing in every column: that is the promise every perf/*
# change makes, and this is where it is kept.
#
#   sh tools/perf_switch_matrix.sh            # luajit on PATH
#   LUA=/path/to/luajit sh tools/perf_switch_matrix.sh
#
# The checks are the ROM-free ones that exercise the mod API end to end:
# the gallery (hooks, effects, upstream fixtures), the no-mod parity gate for
# every hook, the mod example tests and the performance tier logic.  Add a
# path to CHECKS to widen the matrix.
set -u
LUA="${LUA:-luajit}"
CHECKS="${CHECKS:-tests/engine/gate_hooks.lua tests/mod_examples_tests.lua tests/engine/performance_tiers.lua}"

switches=$("$LUA" -e '
  package.path = "./?.lua;" .. package.path
  local P = require("src.core.Performance")
  local names = {}
  for k, v in pairs(P) do
    if type(v) == "boolean" and k ~= "saver" and k ~= "tier" then names[#names + 1] = k end
  end
  table.sort(names)
  print(table.concat(names, " "))
')

run_column() {
  label="$1"; spec="$2"
  for check in $CHECKS; do
    if POKEPORT_PERF="$spec" "$LUA" "$check" >/tmp/perf_matrix_out.txt 2>&1; then
      printf '  ok   %-28s %s\n' "$label" "$check"
    else
      printf '  FAIL %-28s %s\n' "$label" "$check"
      cat /tmp/perf_matrix_out.txt
      failed=1
    fi
  done
}

failed=0
echo "switches: $switches"
run_column "all on" ""
for s in $switches; do
  run_column "$s=0" "$s=0"
done
run_column "all off" "all=0"
if [ "$failed" -ne 0 ]; then
  echo "perf_switch_matrix: FAILED"
  exit 1
fi
echo "perf_switch_matrix: every column agrees"
