import re, sys
from lupa.lua51 import LuaRuntime
src_path, rares_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(src_path, encoding='utf-8').read()
L = LuaRuntime(unpack_returned_tuples=True, register_eval=False, register_builtins=False)
run = L.execute("""
local loadstring, setfenv, assert = loadstring, setfenv, assert
os, io, require, dofile, loadfile, package, debug, module, load, collectgarbage = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
return function(s, p)
  local f = assert(loadstring(s, 'npc'))
  setfenv(f, {})
  f('RareScanner', p)
end
""")
priv = L.table()
run(src, priv)
info = priv.NPC_INFO
ltype = L.globals().type
clara = set(int(x) for x in re.findall(r'^\s*\[(\d+)\]\s*=', open(rares_path, encoding='utf-8').read(), re.M))
def spots_of(t):
    pts = []
    if t['x'] is not None and t['y'] is not None:
        pts.append('%d-%d' % (int(t['x']), int(t['y']))) # (its main spot first)
    ov = t['overlay']
    if ov is not None and ltype(ov) == 'table':
        for _, s in ov.items():
            s = str(s)
            if re.fullmatch(r'\d{1,4}-\d{1,4}', s): pts.append(s)
    # de-dup, keep order
    seen, out = set(), []
    for p in pts:
        if p not in seen: seen.add(p); out.append(p)
    return out
rows, nspots, skipped = [], 0, {'notclara': 0, 'nozone': 0, 'dungeon': 0, 'nospot': 0}
for k, v in info.items():
    nid = int(k)
    if nid not in clara: skipped['notclara'] += 1; continue
    level = v['level']
    level = int(level) if level is not None else 0
    zones = []
    z = v['zoneID']
    if ltype(z) == 'table':
        for zk, zv in z.items():
            zones.append((int(zk), spots_of(zv)))
    else:
        zones.append((int(z or 0), spots_of(v)))
    parts = []
    for zone, pts in sorted(zones):
        if zone == 0: skipped['nozone'] += 1; continue
        if zone >= 100000: skipped['dungeon'] += 1; continue
        if not pts: skipped['nospot'] += 1; continue
        parts.append('%d, "%s"' % (zone, ' '.join(pts)))
        nspots += len(pts)
    if parts:
        rows.append((nid, '  [%d] = { %d, %s },' % (nid, level, ', '.join(parts))))
rows.sort()
head = '''-- Clara Combo Points - where the rares of Rares.lua show, for the world map (RareMap.lua): each one's level and spawn
-- points, map by map, from RareScanner for WoW Forever (1.60.1.9): its IDs, levels and coordinates only, none of its code.
-- [NPC ID] = { level (0: unknown), map ID, "x-y x-y ...", map ID, "...", ... }: its main spot first, then the others where
-- it was seen (patrols), each point in hundredths of a percent of the map ("5120-2060": 51.2 %, 20.6 %). Left out: the rares with no known spot, and the dungeons' (RareScanner's own maps).

local _, ns = ...

ns.RARE_SPOTS = {
'''
open(out_path, 'w', encoding='utf-8').write(head + '\n'.join(r for _, r in rows) + '\n}\n')
print('rares', len(rows), 'spots', nspots, skipped)
