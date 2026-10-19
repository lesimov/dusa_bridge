"""Run tests/oxlib_include/run.lua with lupa's Lua 5.4 (Windows has no lua5.4 binary).

    pip install lupa
    python tests/oxlib_include/run_lupa.py [repo_root] [--loader <file>] [scan_dir ...]
"""
import pathlib
import sys

from lupa import lua54

here = pathlib.Path(__file__).resolve().parent
args = sys.argv[1:] or [str(here.parent.parent)]

lua = lua54.LuaRuntime()
g = lua.globals()
g.arg = lua.table_from({i + 1: a for i, a in enumerate(args)})
g.HARNESS_NO_EXIT = True
script = (here / 'run.lua').read_text(encoding='utf-8')
code = lua.execute(script)
sys.exit(int(code or 0))
