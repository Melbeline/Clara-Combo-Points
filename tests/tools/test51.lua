-- Tooltip Anchor (Modules/TooltipAnchor): the default-anchored tooltips at the game's place, at the
-- mouse by the corner picked (following it), or at the movable anchor; its page and boxes
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false, names = false } }

-- the game's tooltip: placed in its corner by GameTooltip_SetDefaultAnchor
function GameTooltip:ClearAllPoints() self._points = {} end
function GameTooltip:SetPoint(...) self._points = self._points or {}; table.insert(self._points, { ... }) end
function GameTooltip:GetOwner() return self._owner end
function GameTooltip:IsShown() return self._shown end
function GameTooltip_SetDefaultAnchor(tooltip, parent)
  tooltip:SetOwner(parent, "ANCHOR_NONE")
  tooltip:ClearAllPoints()
  tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -100, 100)
end
local sc = UIParent:GetEffectiveScale()
local function near(a, b) return a and math.abs(a - b) < 0.01 end
local function Point() local p = GameTooltip._points; p = p and p[#p]; return p and p[1], p and p[2], p and p[3], p and p[4], p and p[5] end

local ns = {}
S.class = "HUNTER"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")

check(ns:QolRuns("tooltipanchor") and ns.TooltipAnchor ~= nil, "the module runs, on all branches")
M.cursorX, M.cursorY = 500, 300
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent); GameTooltip:Show()
local p, rel, rp, x, y = Point()
check(p == "BOTTOMRIGHT" and rel == UIParent and rp == "BOTTOMLEFT" and near(x, 500 / sc - 4) and near(y, 300 / sc + 4),
  "at the mouse by default, its bottom right corner (" .. tostring(p) .. " " .. tostring(x) .. "," .. tostring(y) .. ")")
check(ns.TooltipAnchorActive() == true, "Leatrix Plus's own cursor anchor kept off")
M.cursorX, M.cursorY = 600, 420
M.Frame(1 / 60)
p, rel, rp, x, y = Point()
check(near(x, 600 / sc - 4) and near(y, 420 / sc + 4), "it follows the mouse (" .. tostring(x) .. "," .. tostring(y) .. ")")
ns.TooltipAnchor.SetCorner("TOPLEFT")
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
p, rel, rp, x, y = Point()
check(p == "TOPLEFT" and near(x, 600 / sc + 18) and near(y, 420 / sc - 24), "top left corner: below and right, clear of the arrow (" .. tostring(x) .. "," .. tostring(y) .. ")")
GameTooltip:Hide()
M.Frame(1 / 60)
local n = #GameTooltip._points
M.Frame(1 / 60)
check(#GameTooltip._points == n, "hidden: no longer followed")

local sw = ns.qolSwitches.tooltipanchor
check(sw and #sw == 2 and sw[1].get() == true and sw[2].get() == false, "two boxes on its page of the Improvements tab: at the mouse, at the anchor")
sw[1].set(false)
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
p, rel, rp, x, y = Point()
check(p == "BOTTOMRIGHT" and rp == "BOTTOMRIGHT" and x == -100 and ns.TooltipAnchorActive() == false, "off: the game's place, Leatrix's free again")

sw[2].set(true)
local anchor = ns.TooltipAnchor.frame
check(anchor:IsShown() and anchor.text:GetText() == "Tooltip Anchor", "the movable anchor shown: Tooltip Anchor")
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
p, rel, rp = Point()
check(p == "TOPLEFT" and rel == anchor and rp == "TOPLEFT", "the tooltip held at the anchor by its corner")
anchor:GetScript("OnDragStart")(anchor)
anchor.GetLeft = function() return 300.4 end
anchor.GetBottom = function() return 200.6 end
anchor:GetScript("OnDragStop")(anchor)
check(ClaraTooltipAnchorDB.x == 300 and ClaraTooltipAnchorDB.y == 201, "moved: its place kept")
local close
for _, c in ipairs(M.frames) do if c._parent == anchor and c._kind == "Button" then close = c end end
close:GetScript("OnClick")(close)
check(not anchor:IsShown() and ns.TooltipAnchor.Mode() == "anchor", "its cross puts it away, the tooltips stay there")

local category
for _, c in ipairs(M.settingsCategories) do if c.name == "Tooltip Anchor" then category = c end end
check(category ~= nil and category.parent == ns.qolThemes.interface, "its page under Interface")
M.ShowSettingsPage(category)
local radios, buttons = 0, 0
for _, c in ipairs(M.frames) do
  if c._parent == category.frame and c._kind == "CheckButton" then radios = radios + 1 end
  if c._parent == category.frame and c._kind == "Button" then buttons = buttons + 1 end
end
check(radios == 7 and buttons == 1, "three places, four corners, a button to move the anchor (" .. radios .. ", " .. buttons .. ")")
ns:OpenQol("tooltipanchor")
check(M.openedCategory == category:GetID(), "opened from the Improvements tab")
out("")
out(fails .. " failure(s)")
