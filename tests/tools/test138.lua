-- The layer with WoW 12.1.7 / Forever 1.60.1's scrambled GUIDs (Layers.lua), what test136 and test137 leave: the
-- verdict of this game build kept: hidden from the login, before any creature; with no verdict, a copy that is no
-- number: hidden at once
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local build = "71000"
GetBuildInfo = function() return "1.60.1", build, "Nov 25 2026", 16001 end
-- (the verdict of an earlier session, with this build)
ClaraComboPointsDB = { layerHidden = "71000", layers = {}, qol = setmetatable({}, { __index = function() return false end }) }
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
out("== this build's verdict: hidden from the login")
check(ns.LayerHidden(), "hidden before any creature is seen")
guids.target = "Creature-0-4395-0-25-299-0000A"
M.Fire("PLAYER_TARGET_CHANGED")
check(Clock():find("hidden by the game", 1, true) and next(ClaraComboPointsDB.layers) == nil, "a creature: still hidden, nothing kept")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
