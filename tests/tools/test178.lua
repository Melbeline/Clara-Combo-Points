-- The game's options set once by Clara (GameFixes: ApplyGameDefaults): each with the version that brought it, set once
-- when that version is new (to the account, or the character for an option kept per character), never again after; the
-- character window's right part (the stats) shown by default (characterFrameCollapsed 0), the ones from before not set
-- again for a player who had them (their own choice since kept).
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false } }
local cvars, setLog = {}, {}
local perChar = { characterFrameCollapsed = false }
C_CVar = {
  GetCVar = function(n) return cvars[n] end,
  SetCVar = function(n, v) cvars[n] = v; setLog[#setLog + 1] = n end,
  GetCVarBool = function(n) return cvars[n] == "1" end,
  GetCVarInfo = function(n) if cvars[n] ~= nil then return cvars[n], "0", false, perChar[n] or false end end,
}
local function Reset(v)
  for k in pairs(cvars) do cvars[k] = nil end
  for k, x in pairs(v) do cvars[k] = x end
  for i = #setLog, 1, -1 do setLog[i] = nil end
end
Reset({ deselectOnClick = "0", autoLootDefault = "0", combinedBags = "1", characterFrameCollapsed = "1" })
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
if not ns.ApplyGameDefaults then out("(no game defaults in this version)"); out(""); out("0 failure(s)"); return end
local entry
for _, d in ipairs(ns.GameDefaults or {}) do if d[1] == "characterFrameCollapsed" then entry = d end end
check(entry and entry[2] == "0", "the character window's right part shown: characterFrameCollapsed 0 among them")

out("== a new player: every one set once")
ns.sv = {}
local n = ns:ApplyGameDefaults()
check(cvars.characterFrameCollapsed == "0" and cvars.autoLootDefault == "1" and cvars.combinedBags == "0", "set (" .. n .. ")")
Reset({ characterFrameCollapsed = "1", autoLootDefault = "0" })
check(ns:ApplyGameDefaults() == 0 and cvars.characterFrameCollapsed == "1", "set back by the player (the console): kept")

out("== a player who had Clara's first ones: only the new one set, theirs kept")
Reset({ deselectOnClick = "0", autoLootDefault = "0", combinedBags = "1", characterFrameCollapsed = "1" })
ns.sv = { gameDefaults = 1, gameDefaultsChars = {} }
n = ns:ApplyGameDefaults()
check(n == 1 and #setLog == 1 and setLog[1] == "characterFrameCollapsed" and cvars.characterFrameCollapsed == "0", "only the window's part (" .. table.concat(setLog, ",") .. ")")
check(cvars.autoLootDefault == "0" and cvars.combinedBags == "1", "their Auto Loot and combined bags as they had them")
check(ns.sv.gameDefaults == 2, "the version kept")
out("== an option the game doesn't have: left out")
Reset({})
ns.sv = {}
check(ns:ApplyGameDefaults() == 0 and cvars.characterFrameCollapsed == nil, "nothing made up")

out("")
out(fails .. " failure(s)")
