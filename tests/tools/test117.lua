-- Names of the friends list's characters the earlier capitals broke (an accented first letter cut in two and kept so:
-- "Éclair Chazal" said "▯clair Chazal", "Clair Chazal has gone offline."): mended. From the list's own key when it is
-- whole; else from a whole name Clara knows (a character seen, its sex kept), heard (a whisper's sender), or a
-- Battle.net friend's character; never another name, never a whole one changed. Clara's AltFriends.lua, or
-- ClassicFriendsList's same code (cfl7).
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
function UnitNameUnmodified(u) if u == "player" then return "Lola", "Moon" end end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }

-- The game's capitals read UTF-8 (imitated): "é" -> "É" whole
local plainUpper = string.upper
local CAPS = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["ç"] = "Ç", ["ô"] = "Ô" }
string.upper = function(s)
  local t, i = {}, 1
  while i <= #s do
    local b = s:byte(i)
    local len = b < 0x80 and 1 or b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
    local ch = s:sub(i, i + len - 1)
    if len == 1 and b < 0x80 then t[#t + 1] = plainUpper(ch) else t[#t + 1] = CAPS[ch] or ch end
    i = i + len
  end
  return table.concat(t)
end

local BAD = "\239\191\189" -- (the replacement sign the game's capitals left)
local bnet = {}
C_BattleNet = C_BattleNet or {}
C_BattleNet.GetFriendAccountInfo = function(i) return bnet[i] end
BNGetNumFriends = function() return #bnet end

local ns = {}
S.class = "ROGUE"; S.locale = "frFR"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local A = ns.AltFriends
ns.sv.altFriends = {
  ["éclair chazal"] = { name = BAD .. "\137clair Chazal" },            -- its key whole
  [BAD .. "\169mile zola"] = { name = BAD .. "\169mile Zola" },        -- key broken too: a character seen
  ["\137lodie dupré"] = { name = "\137lodie Dupré" },                  -- a byte left alone: heard in a whisper
  [BAD .. "\136ve lune"] = { name = BAD .. "\136ve Lune" },            -- a Battle.net friend's character
  [BAD .. "\137clair dupont"] = { name = BAD .. "\137clair Dupont" },  -- nobody known by that name: left as it is
  ["eclair chazal"] = { name = "Eclair Chazal" },                      -- whole: never changed
  ["miss milia"] = { name = "Miss Milia" },                            -- its accented letter lost: heard by its whole name
  ["ren laval"] = { name = "Ren Laval" },                              -- its accented letter lost: a character seen
}
ns.sv.sexes = { ["émile zola"] = 2, ["rené laval"] = 1 }
local function Named(name)
  for key, alt in pairs(A.List()) do if alt.name == name then return key end end
end
local function BrokenLeft() local n = 0 for _, alt in pairs(A.List()) do if A.Broken(alt.name) then n = n + 1 end end return n end

out("== its key whole: its name back from it")
check(Named("Éclair Chazal") == "éclair chazal", "\"Éclair Chazal\", under its key")
check(Named("Eclair Chazal") == "eclair chazal", "the whole \"Eclair Chazal\" left as it is")

out("== at login: from a character seen (its sex kept), and a Battle.net friend's character")
bnet = { { gameAccountInfo = { characterName = "Ève Lune", isOnline = true } } }
M.Fire("PLAYER_LOGIN")
check(Named("Émile Zola") ~= nil and not A.Broken(Named("Émile Zola")), "\"Émile Zola\", under a whole key")
check(Named("Ève Lune") ~= nil, "\"Ève Lune\"")
check(Named("René Laval") == "rené laval", "\"Ren Laval\" (its accented letter lost): \"René Laval\", from the character seen")

out("== heard in a whisper by its whole name")
check(Named("\137lodie Dupré") ~= nil, "still broken before")
M.Fire("CHAT_MSG_WHISPER", "coucou", "Élodie Dupré-Realm", "", "", "Élodie Dupré", "", 0, 0, "", 0, 1, "Player-1-0001")
check(Named("Élodie Dupré") ~= nil, "\"Élodie Dupré\"")
check(Named("Miss Milia") == "miss milia", "\"Miss Milia\" before")
A.Mend("Miss Émilia-Forever")
check(Named("Miss Émilia") ~= nil and Named("Miss Milia") == nil, "\"Miss Milia\" (its É lost): \"Miss Émilia\" once heard whole")
A.Mend("Éclair Chazal")
check(Named("Eclair Chazal") == "eclair chazal", "\"Eclair Chazal\" (an E of its own, not a lost É): left as it is")

out("== nobody known by that name: left, nothing else changed")
check(BrokenLeft() == 1 and Named(BAD .. "\137clair Dupont") ~= nil, "one left broken (" .. BrokenLeft() .. ")")
local count = 0
for _ in pairs(A.List()) do count = count + 1 end
check(count == 8, "eight characters still (" .. count .. ")")
A.Mend("Éclair Chazol")
check(Named(BAD .. "\137clair Dupont") ~= nil, "another surname: not it")
A.List(); A.List()
check(Named("Éclair Chazal") and Named("Élodie Dupré") and Named("Émile Zola"), "the whole names kept as they are, list after list")
out("== never heard whole: renamed by hand (its right-click menu)")
check(A.Rename(BAD .. "\137clair Dupont", "éclair dupont") == true and Named("Éclair Dupont") ~= nil and BrokenLeft() == 0,
  "\"▯clair Dupont\" renamed \"Éclair Dupont\" (typed lower-case: its capitals, its É whole)")
check(A.Rename("Éclair Dupont", "Eclair Chazal") == false and Named("Éclair Dupont") ~= nil, "a name already in the list: refused, left as it was")
local n2 = 0 for _ in pairs(A.List()) do n2 = n2 + 1 end
check(n2 == 8, "still eight characters (" .. n2 .. ")")
string.upper = plainUpper
out(string.format("\n%d failure(s)", fails))
return fails
