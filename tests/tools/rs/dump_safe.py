import re, sys, json
from lupa.lua51 import LuaRuntime
path, outp = sys.argv[1], sys.argv[2]
src = open(path, encoding='utf-8').read()
L = LuaRuntime(unpack_returned_tuples=True, register_eval=False, register_builtins=False)
# the data file runs in an empty environment: no os, io, require, load functions
run = L.execute("""
local loadstring, setfenv, assert = loadstring, setfenv, assert
os, io, require, dofile, loadfile, package, debug, module, load, collectgarbage = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
return function(s, p)
  local f = assert(loadstring(s, 'npc'))
  setfenv(f, { pairs = pairs, ipairs = ipairs, type = type, tonumber = tonumber, tostring = tostring, table = { insert = table.insert } })
  f('RareScanner', p)
end
""")
priv = L.table()
run(src, priv)
info = priv.NPC_INFO
ltype = L.globals().type
names = {}
for m in re.finditer(r'\[(\d+)\]\s*=\s*\{', src):
    nid = int(m.group(1)); i = m.end(); depth = 1
    while depth and i < len(src):
        c = src[i]
        if c == '{': depth += 1
        elif c == '}': depth -= 1
        i += 1
    rest = src[i:i+200].split('\n')[0]
    cm = re.search(r'--\s*(.+)$', rest)
    names.setdefault(nid, cm.group(1).strip() if cm else None)
out = []
for k, v in info.items():
    keys = {}
    for kk, vv in v.items():
        if ltype(vv) == 'table':
            keys[kk] = 'table' if kk != 'zoneID' else sorted([int(z) for z in vv.keys()])
        else:
            keys[kk] = vv
    out.append({'id': int(k), 'name': names.get(int(k)), **{str(a): b for a, b in keys.items()}})
json.dump(out, open(outp, 'w'), ensure_ascii=False, indent=0, default=str)
print(len(out))
