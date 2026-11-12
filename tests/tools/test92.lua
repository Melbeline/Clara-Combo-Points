-- The minimap's tracking button (GameFixes.lua): the right button's release added to the game's button (it hears
-- the left one only), a right-click turns the active tracking spell off by the game's tracking call; the tooltip says it
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local registered
local button = CreateFrame("Button", "TestTrackingButton", UIParent)
function button:RegisterForMouse(...) registered = { ... } end
MinimapCluster = { Tracking = { Button = button } }
local tracking = {
  { name = "Find Herbs", type = "spell", active = false },
  { name = "Track Beasts", type = "spell", active = true },
  { name = "Repair", type = "townsfolk", active = true },
}
local turnedOff = {}
C_Minimap = C_Minimap or {}
C_Minimap.GetNumTrackingTypes = function() return #tracking end
C_Minimap.GetTrackingInfo = function(i) return tracking[i] end
C_Minimap.SetTracking = function(i, on) tracking[i].active = on if not on then turnedOff[#turnedOff + 1] = tracking[i].name end end

local ns = {}
S.class = "HUNTER"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")

local hears = {}
for _, v in ipairs(registered or {}) do hears[v] = true end
check(hears.LeftButtonDown and hears.LeftButtonUp and hears.RightButtonUp, "the right button's release added, the left kept")

out("== the tooltip")
local lines = {}
local realAdd, realOwned = GameTooltip.AddLine, GameTooltip.IsOwned
GameTooltip.IsOwned = function(_, f) return f == button end
GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
local enter = button:GetScript("OnEnter")
if enter then enter(button) end
GameTooltip.AddLine, GameTooltip.IsOwned = realAdd, realOwned
check(lines[1] == "Right-click: turn Track Beasts off", "says the right-click (" .. tostring(lines[1]) .. ")")

out("== a right-click")
local up = button:GetScript("OnMouseUp")
up(button, "LeftButton")
check(#turnedOff == 0, "a left-click: nothing (the game's menu)")
up(button, "RightButton")
check(#turnedOff == 1 and turnedOff[1] == "Track Beasts", "Track Beasts turned off, the townsfolk tracking kept")
up(button, "RightButton")
check(#turnedOff == 1, "nothing tracked: nothing more")
out(string.format("\n%d failure(s)", fails))
return fails
