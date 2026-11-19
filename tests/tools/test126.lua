-- UnitScan: /unitscan name looks for that creature, typed again no longer (a rare of the default list too: taken off,
-- back again); Spectral Stalker (a common mob of Deadwind Pass) no longer in the default list
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70959", "Nov 17 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }
local printed = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end printed[#printed + 1] = table.concat(t, " ") end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local function Said() return printed[#printed] or "" end
local function Has(t, s) return t:find(s, 1, true) ~= nil end

out("== Spectral Stalker: no longer a rare of the list")
local found = false
for _, names in pairs(ns.RARES or {}) do if names[1] == "Spectral Stalker" then found = true end end
check(not found and next(ns.RARES) ~= nil, "not in the default list (the others kept)")

out("== /unitscan name: looked for, typed again: no longer")
local cmd = SlashCmdList.CLARAUNITSCAN
check(SLASH_CLARAUNITSCAN1 == "/unitscan" and cmd, "the command /unitscan")
cmd("Gnarlpine Ambusher")
check(ns.sv.scan.names and ns.sv.scan.names["gnarlpine ambusher"] == "Gnarlpine Ambusher" and Has(Said(), "Gnarlpine Ambusher added"),
  "added, said so (" .. Said() .. ")")
cmd("  gnarlpine AMBUSHER ")
check(ns.sv.scan.names == nil and Has(Said(), "removed"), "typed again (any case, spaces): removed")
cmd("")
check(Has(Said(), "/unitscan"), "nothing typed: how to use it")

out("== a rare of the default list: taken off, back again")
local id, rare
for k, names in pairs(ns.RARES) do id, rare = k, names[1] break end
cmd(rare)
check(ns.sv.scan.skip and ns.sv.scan.skip[id] and Has(Said(), "removed"), rare .. ": taken off the watch")
cmd(rare)
check(ns.sv.scan.skip == nil and Has(Said(), "added"), rare .. ": back on it")
out(string.format("\n%d failure(s)", fails))
return fails
