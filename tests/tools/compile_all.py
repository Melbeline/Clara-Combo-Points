import sys, os
from lupa import lua51
L = lua51.LuaRuntime()
ls = L.eval("function(s, n) local f, e = loadstring(s, n) return e end")
bad = 0
for root, _, files in os.walk(sys.argv[1]):
    for f in files:
        if f.endswith(".lua"):
            p = os.path.join(root, f)
            e = ls(open(p, "rb").read(), "@" + p)
            if e: print(e); bad += 1
print("compile errors:", bad)
