-- /cl souris over a bag item: what its right-click reads (the game's ContainerFrameItemButton_OnClick and on), each value
-- an addon wrote named with that addon (the game's issecurevariable); none: said so; not over a bag item: no section
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({}, { __index = function() return false end }) }
-- the game's: a bag window and its item button; MerchantFrame, C_Container
ContainerFrame1 = CreateFrame("Frame", "ContainerFrame1", UIParent)
local item = CreateFrame("Button", nil, ContainerFrame1)
function item:GetBagID() return 0 end
MerchantFrame = CreateFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame.selectedTab = 1
C_Container = C_Container or {}
C_Container.UseContainerItem = C_Container.UseContainerItem or function() end
-- written by addons: (table, key) or global name -> the addon
local written = {}
function issecurevariable(t, key)
  if key == nil then key, t = t, _G end
  local by = written[t] and written[t][key]
  if by then return false, by end
  return true, nil
end
local function Wrote(t, key, addon) written[t] = written[t] or {}; written[t][key] = addon end

S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")

out("== nothing written by an addon")
local lines = ns:BagClickTaintReport(item)
check(lines[1] and lines[1]:find("none written by an addon", 1, true) ~= nil and #lines == 1, lines[1] or "?")
local n = tonumber(lines[1]:match("reads, (%d+) values"))
check(n and n > 60, "the values its right-click reads, checked: " .. tostring(n))

out("== written by addons: each named with its addon")
item.bagID = 0
Wrote(item, "bagID", "SomeBagAddon")
Wrote(_G, "MerchantFrame", "ClaraComboPoints")
Wrote(C_Container, "UseContainerItem", "OtherAddon")
Wrote(MerchantFrame, "selectedTab", "ClaraComboPoints")
lines = ns:BagClickTaintReport(item)
local text = table.concat(lines, "\n")
check(lines[1]:find("written by an addon:", 1, true) ~= nil, "said so")
check(text:find("MerchantFrame (ClaraComboPoints)", 1, true) ~= nil, "a global the game reads")
check(text:find("C_Container.UseContainerItem (OtherAddon)", 1, true) ~= nil, "a function in a table")
check(text:find("MerchantFrame.selectedTab (ClaraComboPoints)", 1, true) ~= nil, "a window's field")
check(text:find(".bagID (SomeBagAddon)", 1, true) ~= nil, "the item button's own field")

out("== not over a bag item: no section")
GetMouseFoci = function() return { UIParent } end
check(#ns:BagClickTaintReport() == 0, "nothing")
GetMouseFoci = function() return { item } end
check(#ns:BagClickTaintReport() > 1, "over it: found by the mouse")

out(string.format("\n%d failure(s)", fails))
return fails
