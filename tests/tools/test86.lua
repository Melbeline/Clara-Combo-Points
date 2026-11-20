-- UnitScan's default list with RareScanner's rares (Rares.lua): a rare new in WoW Forever (Durotar's Dustwind Eggtender)
-- and one of the new zones' (the Zephras Isles' Den'dralass) give the alert by their ID; the test creature and the
-- friendly quest NPCs left out never do.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70888", "Nov 10 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false } }
local CVARS = { EnableBlinkApplicationIcon = "0", nameplateMaxDistance = "20" }
C_CVar = { GetCVar = function(n) return CVARS[n] end, SetCVar = function(n, v) CVARS[n] = tostring(v) end }
ChatFrameUtil = { AddMessageEventFilter = function() end }
EventRegistry = { RegisterCallback = function() end }
function GetInstanceInfo() return "Durotar", "none", 0, "", 5, 0, false, 0 end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
S.channels = { "General" }
S.map = { id = 1411, x = .51, y = .19, name = "Durotar" }
S.units = {}
M.now = 1000
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
local n = 0
for _ in pairs(ns.RARES) do n = n + 1 end
check(n == 486, "486 rares in the default list (" .. n .. ")")
check(ns.RARES[276194] and ns.RARES[276194][1] == "Dustwind Eggtender", "Dustwind Eggtender by its ID")
check(ns.RARES[260468] and ns.RARES[260468][1] == '"Pyromancer" Braxton', "a name with quotes kept whole")
check(not ns.RARES[277981] and not ns.RARES[11383] and not ns.RARES[12116], "the test creature and the friendly quest NPCs left out")
local flashed = M.flashed or 0
S.units.nameplate1 = { name = "Dustwind Eggtender", guid = "Creature-0-4395-1-25-276194-0000ABC", level = 12, classification = "rare" }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Run()
local secure = ClaraScanButton
check(secure and secure:IsShown() and secure.title:GetText() == "Dustwind Eggtender", "a new Forever rare in sight: the alert (" .. tostring(secure and secure.title:GetText()) .. ")")
check((M.flashed or 0) == flashed + 1, "the taskbar flashed")
M.now = M.now + 120
S.units.nameplate2 = { name = "Den'dralass", guid = "Creature-0-4395-1-25-250936-0000ABD", level = 12, classification = "rare" }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
Run()
check(ClaraScanButton.title:GetText() == "Den'dralass", "a Zephras Isles rare: the alert")
M.now = M.now + 120
local before = M.flashed or 0
S.units.nameplate3 = { name = "High Priestess Hai'watna", guid = "Creature-0-4395-1-25-11383-0000ABE", level = 57, classification = "normal" }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
Run()
check((M.flashed or 0) == before, "a friendly quest NPC left out: no alert")
out(string.format("\n%d failure(s)", fails))
return fails
