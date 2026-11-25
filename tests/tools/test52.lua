-- Alt + left click on a bag item disenchants it (Disenchant.lua): one click, one Disenchant, on that
-- item; enchanters only, what can be disenchanted only, not in a fight, its box in the game's options
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false } }

-- the bags: 1 a green sword, 2 a grey shirt, 3 a potion
local SLOTS = { [1] = { itemID = 101, quality = 2 }, [2] = { itemID = 102, quality = 0 }, [3] = { itemID = 103, quality = 1 } }
local CLASS = { [101] = 2, [102] = 4, [103] = 0 }
C_Container = C_Container or {}
C_Container.GetContainerItemInfo = function(bag, slot) return bag == 0 and SLOTS[slot] or nil end
C_Item.GetItemInfoInstant = function(id) return id, "x", "y", "", 1, CLASS[id], 0 end
function IsAltKeyDown() return M.alt == true end
function GameTooltip:GetOwner() return self._owner end
function GameTooltip:SetBagItem(bag, slot) self._bagItem = bag .. ":" .. slot end

local ns = {}
S.class = "MAGE"; S.locale = "enUS"
S.knownSpells = { [13262] = true }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")

-- a bag item button, the cursor on it, its tooltip shown by the game
local function ItemButton(slot)
  local b = CreateFrame("Button", nil, UIParent)
  b:SetSize(37, 37); b:SetPoint("CENTER", UIParent, "CENTER", slot * 40, 0)
  b.slot = slot
  return b
end
local items = { ItemButton(1), ItemButton(2), ItemButton(3) }
local function Hover(i)
  M.CursorOn(items[i])
  GameTooltip:SetOwner(items[i], "ANCHOR_NONE")
  GameTooltip:SetBagItem(0, i)
end
local de = ClaraDisenchantButton

Hover(1)
check(not de:IsShown(), "no Alt: nothing over the item")
M.alt = true
M.Fire("MODIFIER_STATE_CHANGED", "LALT", 1)
check(de:IsShown() and de:GetAttribute("target-bag") == 0 and de:GetAttribute("target-slot") == 1, "Alt held: over the green sword, aimed at it")
M.casts = {}
de:Click("LeftButton")
check(#M.casts == 1 and M.casts[1] == 13262, "a click: one Disenchant")
check(not de:IsShown(), "then put away (the next hover brings it back)")
M.alt = false
M.Fire("MODIFIER_STATE_CHANGED", "LALT", 0)
M.alt = true
Hover(2)
check(not de:IsShown(), "a grey shirt: not disenchantable")
Hover(3)
check(not de:IsShown(), "a potion: not disenchantable")
Hover(1)
check(de:IsShown(), "the sword again")
M.alt = false
M.Fire("MODIFIER_STATE_CHANGED", "LALT", 0)
check(not de:IsShown(), "Alt let go: gone")

S.knownSpells = {}
M.alt = true
Hover(1)
check(not de:IsShown(), "not an enchanter: nothing")
S.knownSpells = { [13262] = true }

ns:SetDisenchantClick(false)
Hover(1)
check(not de:IsShown() and ClaraComboPointsDB.disenchantClick == false, "its box off: nothing")
ns:SetDisenchantClick(true)
Hover(1)
check(de:IsShown(), "on again")
M.Fire("PLAYER_REGEN_DISABLED")
S.inCombat = true
check(not de:IsShown(), "a fight: put away before it")
Hover(1)
check(not de:IsShown(), "and not in it")
S.inCombat = false

local category
for _, c in ipairs(M.settingsCategories) do if c.name == " Clara" then category = c end end
M.ShowSettingsPage(category)
local page = category.frame
check(page.disenchant and page.disenchant:GetChecked() == true, "its box in Esc > Options > AddOns > Clara")
check(de:GetAttribute("useOnKeyDown") == false, "it acts on the release, whatever the game's cast-on-key-down")
local report = ns.DisenchantReport and ns:DisenchantReport() or ""
check(report:find("Alt-click disenchant: box true, Disenchant known", 1, true), "its line in the mouse report (" .. report .. ")")
out("")
out(fails .. " failure(s)")
