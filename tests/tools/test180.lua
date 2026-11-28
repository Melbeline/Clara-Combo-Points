-- The group's and the raid's members above everything on the world map and the minimap (MapGroup.lua), at Classic
-- 1.15.9's size on the map (16). The world map: the game's layer of the group's
-- members set above the map's highest icon (Questie's from 2016 up), plus one, never under 2500; kept when the game sets
-- its place again or the map changes; not in a fight while the layer is protected (just after); the box unticked: back
-- to the game's own place.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false } }

-- the world map: its canvas, Questie's icons on it, the game's group layer at its own place
local function Child(level) return { GetFrameLevel = function() return level end } end
local children = { Child(510), Child(2016), Child(2041), Child(2098) }
local canvas = { GetChildren = function() return unpack(children) end }
local protected, gamePlace = false, 420
local pin = { level = gamePlace, fixed = false }
function pin:GetFrameLevel() return self.level end
function pin:SetFrameLevel(l) self.level = l end
function pin:SetFixedFrameLevel(v) self.fixed = v end
function pin:IsProtected() return protected end
function pin:ApplyFrameLevel() self.level = gamePlace end
-- (its sizes: WoW Forever's 11 and 8, divided by the map's zoom, as the game does)
local canvasScale = 2
pin.sizes = {}
function pin:SetPinSize(unit, size) self.sizes[unit] = size end
function pin:SynchronizePinSizes() self.sizes.party = 11 / canvasScale; self.sizes.raid = 8.25 / canvasScale end
local shown = true
WorldMapFrame = { scripts = {} }
function WorldMapFrame:GetCanvas() return canvas end
function WorldMapFrame:GetCanvasScale() return canvasScale end
function WorldMapFrame:IsShown() return shown end
function WorldMapFrame:HookScript(name, fn) self.scripts[name] = fn end
function WorldMapFrame:OnMapChanged() end
function WorldMapFrame:RefreshAllDataProviders() end
function WorldMapFrame:EnumeratePinsByTemplate(t)
  local done = false
  return function() if done or t ~= "GroupMembersPinTemplate" then return nil end done = true return pin end
end
function pin:GetMap() return WorldMapFrame end
children[#children + 1] = pin

-- the minimap, Questie's icons on it at their fixed height
Minimap = CreateFrame("Frame", "Minimap", UIParent)
local mmKids = { Child(2030), Child(2077) }
Minimap.GetChildren = function() return unpack(mmKids) end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.MapGroupRaise then out("(not in this version)"); out(""); out("0 failure(s)"); return end
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
Run()

out("== the map shown: the group above every icon")
check(pin.level == 2500 and pin.fixed, "above Questie's (2098): 2500 (" .. pin.level .. "), kept as the map's level changes")
children[#children + 1] = Child(3100)
WorldMapFrame:OnMapChanged(); Run()
check(pin.level == 3101, "an icon higher still: one above it (" .. pin.level .. ")")
out("== the members' size as in Classic 1.15.9: 16 for the group and the raid")
check(pin.sizes.party == 8 and pin.sizes.raid == 8, "16 at the map's zoom 2: 8 (" .. tostring(pin.sizes.party) .. ")")
canvasScale = 4
pin:SynchronizePinSizes()
check(pin.sizes.party == 4 and pin.sizes.raid == 4, "zoomed in, the game's sizes set again: 16 again (" .. tostring(pin.sizes.party) .. ")")
canvasScale = 2
out("== the game setting its place again: raised again")
pin:ApplyFrameLevel()
check(pin.level == 3101, "kept above (" .. pin.level .. ")")
out("== in a fight, the layer protected: left, raised after")
table.remove(children)
protected = true; S.inCombat = true
pin:ApplyFrameLevel()
check(pin.level == gamePlace, "left at the game's place in the fight")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(pin.level == 2500, "after the fight: above again (" .. pin.level .. ")")
protected = false
out("== the box unticked: the game's own place; ticked: above again")
ns:SetMapGroupOnTop(false)
check(pin.level == gamePlace and not pin.fixed and ClaraComboPointsDB.mapGroupOnTop == false, "back to the game's place")
check(pin.sizes.party == 5.5, "and the game's size (" .. tostring(pin.sizes.party) .. ")")
pin:ApplyFrameLevel()
check(pin.level == gamePlace, "left there")
ns:SetMapGroupOnTop(true)
check(pin.level == 2500 and ClaraComboPointsDB.mapGroupOnTop == nil and pin.sizes.party == 8, "above again, 16 again")

out("== the minimap: a dot of Clara's on each member, above every icon there (HereBeDragons placing it)")
local added, removed = {}, {}
local HBD = LibStub:NewLibrary("HereBeDragons-2.0", 1)
function HBD:GetUnitWorldPosition(unit) local y, x, _, i = UnitPosition(unit) return x, y, i end
local Pins = LibStub:NewLibrary("HereBeDragons-Pins-2.0", 1)
function Pins:AddMinimapIconWorld(ref, icon, inst, x, y, edge) added[#added + 1] = { "world", icon, inst, x, y }; icon:Show() end
function Pins:AddMinimapIconMap(ref, icon, map, x, y, parent, edge) added[#added + 1] = { "map", icon, map, x, y }; icon:Show() end
function Pins:RemoveMinimapIcon(ref, icon) removed[#removed + 1] = icon end
local where = { party1 = { 100, 200, 0, 1 }, party2 = { 300, 400, 0, 1 } }
function UnitPosition(u) local w = where[u] if w then return w[1], w[2], w[3], w[4] end end
local members = { party1 = "MAGE", party2 = "PRIEST" }
local oldExists, oldClass = UnitExists, UnitClass
UnitExists = function(u) return members[u] ~= nil or oldExists(u) end
UnitClass = function(u) if members[u] then return members[u], members[u] end return oldClass(u) end
function UnitIsConnected(u) return members[u] ~= nil end
RAID_CLASS_COLORS = { MAGE = { r = .25, g = .78, b = .92 }, PRIEST = { r = 1, g = 1, b = 1 } }
S.group = "party"
ns.MapGroupDots()
local d1, d2 = ns.MapGroupDotOf("party1"), ns.MapGroupDotOf("party2")
check(d1 and d2 and #added == 2 and added[1][1] == "world" and added[1][4] == 200 and added[1][5] == 100, "a dot for each, at their world place")
check(d1:GetFrameLevel() == 2500 and d2:GetFrameLevel() == 2500, "above Questie's minimap icons (2077): 2500 (" .. d1:GetFrameLevel() .. ")")
ns.MapGroupDots()
check(#added == 2, "not moved: not given again")
where.party1 = { 110, 200, 0, 1 }
ns.MapGroupDots()
check(#added == 3 and added[3][2] == d1, "moved: given again")
out("== in a place without world coordinates: the place on the player's map")
where.party2 = nil
C_Map = C_Map or {}
C_Map.GetBestMapForUnit = function() return 1429 end
C_Map.GetPlayerMapPosition = function(map, u) if u == "party2" then return { GetXY = function() return 0.4, 0.6 end } end end
ns.MapGroupDots()
check(added[#added][1] == "map" and added[#added][3] == 1429 and added[#added][2] == d2, "on map 1429")
out("== a member gone: their dot taken off")
members.party2 = nil
ns.MapGroupDots()
check(removed[#removed] == d2 and not d2:IsShown(), "taken off")
out("== the box unticked: no dot")
ns:SetMapGroupOnTop(false)
ns.MapGroupDots()
check(not d1:IsShown(), "none")
ns:SetMapGroupOnTop(true)
S.group = nil

out("")
out(fails .. " failure(s)")
