-- The layer with WoW 12.1.7 / Forever 1.60.1's scrambled GUIDs (Layers.lua), what test136 leaves (and test138): a
-- verdict of an older game build looked at again; three copies at once (the target, the mouse and the nameplates are
-- always in one): hidden, kept for this build
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local build = "71000"
GetBuildInfo = function() return "1.60.1", build, "Nov 25 2026", 16001 end
-- (the verdict of an earlier session, with an older build: looked at again)
ClaraComboPointsDB = { layerHidden = "70959", qol = setmetatable({}, { __index = function() return false end }) }
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

out("== a verdict of an older build: looked at again")
check(not ns.LayerHidden() and ClaraComboPointsDB.layerHidden == nil, "not hidden, the old verdict dropped")

out("== three copies at once: hidden")
guids.target = "Creature-0-4395-0-25-299-0000A"
guids.mouseover = "Creature-0-4395-0-26-300-0000B"
guids.nameplate1 = "Creature-0-4395-0-27-301-0000C"
plates = { "nameplate1" }
local t = Clock()
check(ns.LayerHidden() and t:find("hidden by the game", 1, true), "target, mouse and a nameplate in three copies: hidden (" .. t .. ")")
check(ClaraComboPointsDB.layerHidden == build, "kept for this build")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
