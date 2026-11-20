-- The layer with WoW 12.1.7 / Forever 1.60.1's scrambled GUIDs (Layers.lua), what test136 to test138 leave: a copy
-- that is no number (the game's scrambling may write it so): hidden at once, kept for this build
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local build = "71000"
GetBuildInfo = function() return "1.60.1", build, "Nov 25 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({}, { __index = function() return false end }) }
local guids, instance = {}, { name = "Elwynn", kind = "none", map = 0 }
function UnitGUID(u) if u == "player" then return "Player-1-00000001" end return guids[u] end
function GetInstanceInfo() return instance.name, instance.kind, 0, "", 5, 0, false, instance.map end
function UnitIsPlayer(u) return false end
function GameTime_UpdateTooltip() GameTooltip:AddLine("Time Info") end
local plates = {}
C_NamePlate = { GetNamePlates = function() local t = {} for i, u in ipairs(plates) do t[i] = { namePlateUnitToken = u } end return t end }
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
while M.timers and #M.timers > 0 do M.RunTimer() end
local function Clock() GameTooltip:SetOwner(UIParent); GameTime_UpdateTooltip(); return table.concat(GameTooltip._lines, " | ") end
out("== a copy that is no number")
check(not ns.LayerHidden(), "not hidden at first")
guids.target = "Creature-0-a8f3-0-k2z9-299-q0w9e8"
M.Fire("PLAYER_TARGET_CHANGED")
check(ns.LayerHidden() and Clock():find("hidden by the game", 1, true), "hidden at once")
check(ClaraComboPointsDB.layerHidden == "71000", "kept for this build")
guids.target = "Player-1-0002"
M.Fire("PLAYER_TARGET_CHANGED")
check(ns.LayerHidden(), "a player's GUID changes nothing")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
