import random, time, os, sys
from lupa import lua51
random.seed(1)
names = ["Miss Émilia", "Elle Durand", "Piou Moreau", "Lola Moon", "Grumpy Troll", "Éclair Chazal"]
chans = ["[2. Commerce]", "[1. Général]", "[4. RechercheDeGroupe]", "[Guilde]", ""]
words = "LFM Brd full run need tank heal wts enchant crusader 5g pst achète vends cuir épais lingots de thorium groupe pour la quête".split()
def line():
    n = random.choice(names)
    link = '|cff1eff00|Hitem:%d::::::::60:::::|h[Objet %d]|h|r' % (random.randint(1000, 20000), random.randint(1, 999)) if random.random() < 0.3 else ""
    text = " ".join(random.choice(words) for _ in range(random.randint(4, 18)))
    return '|cff%02x%02x%02x%s |Hplayer:%s|h[|cffc79c6e%s|r]|h: %s %s' % (random.randint(0,255), random.randint(0,255), random.randint(0,255), random.choice(chans), n, n, text, link)
def write(path, per, windows):
    with open(path, "w", encoding="utf-8") as f:
        f.write("ClaraChatHistoryDB = {\n\t[\"time\"] = 1763590000,\n")
        for w in windows:
            f.write("\t[%d] = {\n" % w)
            for _ in range(per):
                s = line().replace("\\", "\\\\").replace('"', '\\"')
                f.write('\t\t"%s", -- [x]\n' % s)
            f.write("\t},\n")
        f.write("}\n")
L = lua51.LuaRuntime()
for per in (10000, 20000):
    for windows in ((1,), (1, 3, 4)):
        path = "sv_%d_%d.lua" % (per, len(windows))
        write(path, per, windows)
        size = os.path.getsize(path) / 1e6
        src = open(path, encoding="utf-8").read()
        best = 1e9
        for _ in range(3):
            t = time.perf_counter()
            L.execute(src)
            best = min(best, time.perf_counter() - t)
        # Clara's own work at login: each line's color read back, then handed to the window (a stub here)
        t = time.perf_counter()
        L.execute('''
          local n = 0
          local function Add(t, r, g, b) n = n + 1 end
          for i, list in pairs(ClaraChatHistoryDB) do
            if type(list) == "table" then
              for k = 1, #list do
                local hex, rest = list[k]:match("^|cff(%x%x%x%x%x%x)(.*)$")
                if hex then Add(rest, tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
                else Add(list[k]) end
              end
            end
          end
        ''')
        restore = time.perf_counter() - t
        print("%6d lines x %d window(s): file %5.1f MB, read %5.0f ms, Clara's own restore work %4.0f ms" % (per, len(windows), size, best * 1000, restore * 1000))
