-- The group's and the raid's members above everything on the world map (MapGroup.lua): the game's layer of the group's
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
local shown = true
WorldMapFrame = { scripts = {} }
function WorldMapFrame:GetCanvas() return canvas end
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
pin:ApplyFrameLevel()
check(pin.level == gamePlace, "left there")
ns:SetMapGroupOnTop(true)
check(pin.level == 2500 and ClaraComboPointsDB.mapGroupOnTop == nil, "above again")

out("")
out(fails .. " failure(s)")
