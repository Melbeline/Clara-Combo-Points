"""Run the Lua mock tests with Lua 5.1 (lupa). Usage: run.py <tools_dir> <addon_dir> [script]"""
import sys
from lupa import lua51

tools, addon = sys.argv[1], sys.argv[2]
script = sys.argv[3] if len(sys.argv) > 3 else "test.lua"
L = lua51.LuaRuntime(unpack_returned_tuples=True)
import os as _os
from PIL import ImageFont as _IF
_FONT_CACHE = {}
def measure(path, size, text):
    path = str(path); size = max(1, int(round(float(size))))
    if path.startswith("Interface\\AddOns\\ClaraComboPoints\\"):
        file = _os.path.join(addon, path.split("ClaraComboPoints\\", 1)[1].replace("\\", "/")); squeeze = 1.0
    else:
        file = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
        squeeze = 0.82 if path.upper().endswith("ARIALN.TTF") else 1.0
        if path.startswith("OBJ:GameFont"):
            squeeze = 1.15  # the game's font objects use Friz Quadrata, wider than this one
    key = (file, size)
    if key not in _FONT_CACHE:
        _FONT_CACHE[key] = _IF.truetype(file, size)
    return _FONT_CACHE[key].getlength(str(text)) * squeeze
g = L.globals()
g.MEASURE = measure
g.ADDON_DIR = addon
g.TOOLS_DIR = tools
L.execute(open(f"{tools}/wowmock.lua").read())
res = L.execute(open(f"{tools}/{script}").read())
sys.exit(0 if not res else 1)
