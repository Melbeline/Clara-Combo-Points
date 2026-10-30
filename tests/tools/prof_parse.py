import sys, os, time
from lupa import lua51
L = lua51.LuaRuntime()
d = sys.argv[1]
toc = open(os.path.join(d, "ClaraComboPoints.toc"), encoding="utf-8").read().splitlines()
total = {}
ls = L.eval("loadstring")
for line in toc:
    if line.startswith("#") or not line.strip().endswith(".lua"): continue
    path = os.path.join(d, line.strip().replace("\\", "/"))
    src = open(path, "rb").read()
    t = time.perf_counter()
    for _ in range(5): ls(src)
    dt = (time.perf_counter() - t) / 5
    key = "Modules/" + line.split("\\")[1] if line.startswith("Modules") else "Clara"
    total[key] = total.get(key, 0) + dt
for k, v in sorted(total.items(), key=lambda x: -x[1]): print(f"{v*1000:7.1f} ms  {k}")
