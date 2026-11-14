#!/usr/bin/env python3
"""Stand-in tests for ghillie_gud.script (no game needed).

Each .lua file here stubs the Anomaly engine API (db.actor, ini_sys, IsMoveState,
get_player_hud, ui_mcm, ...), loads the real script and asserts the results
(multipliers, arm calls, MCM reads). A parse error or failed assertion stops the
run with a nonzero exit code. These are mocked engine tests, not in-game checks.

Needs LuaJIT via lupa:  pip install lupa
Run from the repo root:  python tests/run.py
"""
import os
import sys
from pathlib import Path

try:
    from lupa.luajit21 import LuaRuntime
except ImportError:
    sys.exit("needs lupa with LuaJIT: pip install lupa")

root = Path(__file__).resolve().parent.parent

# Shared helpers for every scenario. print goes through Python so the output
# stays in order with the runner's own lines.
PRELUDE = r"""
local pp = python_print
function print(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	pp(table.concat(t, "\t"))
end
function assert_close(actual, expected, label)
	assert(type(actual) == "number" and math.abs(actual - expected) < 1e-9,
		string.format("%s: expected %.12g, got %s", label, expected, tostring(actual)))
end
function assert_eq(actual, expected, label)
	assert(actual == expected,
		string.format("%s: expected %q, got %q", label, tostring(expected), tostring(actual)))
end
"""


def new_runtime():
    lua = LuaRuntime()
    lua.globals().python_print = lambda s: print(s, flush=True)
    lua.execute(PRELUDE)
    return lua


parse = LuaRuntime().eval("function(s) local f, e = loadstring(s); return e end")
for name in ["ghillie_gud.script", "ghillie_gud_mcm.script"]:
    src = (root / "gamedata/scripts" / name).read_text(encoding="utf-8")
    error = parse(src)
    if error is not None:
        sys.exit(f"parse {name}: {error}")
    print(f"parse {name}: OK", flush=True)

os.chdir(root)
for test in sorted((root / "tests").glob("*.lua")):
    print(f"\n===== {test.name}", flush=True)
    new_runtime().execute(test.read_text(encoding="utf-8"))

print("\nall scenarios passed")
