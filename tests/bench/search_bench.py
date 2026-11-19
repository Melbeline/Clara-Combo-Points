import time, random
from lupa import lua51
L = lua51.LuaRuntime()
src_names = open('/home/user/Clara-Combo-Points/ClaraComboPoints/SpellNames.lua', encoding='utf-8').read()
start = src_names.index('local ACCENTS = {}'); end = src_names.index('ns.NAME_LANGS')
search = open('/home/user/Clara-Combo-Points/ClaraComboPoints/ChatSearch.lua', encoding='utf-8').read()
a = search.index('local function Shown(text)'); b = search.index('---------------------------------------------------------------------------\n-- A window\'s search')
L.execute('ns = {}; L = {}; issecretvalue = function() return false end\n' + src_names[start:end] + '\nlocal issecret = issecretvalue\n' + search[a:b] + '\nFIND = Find')
L.execute('''
  local words = { "LFM", "Brd", "full", "run", "need", "tank", "heal", "wts", "enchant", "crusader", "5g", "pst", "achète", "vends", "cuir", "épais", "thorium", "groupe" }
  W = { lines = {} }
  function W:GetNumMessages() return #self.lines end
  function W:GetMessageInfo(i) return self.lines[i] end
  math.randomseed(1)
  for i = 1, 50000 do
    local t = {}
    for k = 1, math.random(4, 18) do t[#t + 1] = words[math.random(#words)] end
    local link = (math.random() < 0.3) and ("|cff1eff00|Hitem:" .. math.random(1000, 20000) .. "::::::::60:::::|h[Objet " .. i .. "]|h|r") or ""
    W.lines[i] = ("|cff%02x%02x%02x[2. Commerce] |Hplayer:Miss Émilia|h[|cffc79c6eMiss Émilia|r]|h: %s %s"):format(math.random(0,255), math.random(0,255), math.random(0,255), table.concat(t, " "), link)
  end
''')
for label in ("first search (nothing read yet)", "next search (lines already read)", "another word"):
    q = "crusader" if label != "another word" else "thorium epais"
    t = time.perf_counter(); n = L.eval('#FIND(W, "%s")' % q); dt = time.perf_counter() - t
    print("%-34s %6.0f ms  (%d matches)" % (label, dt * 1000, n))
