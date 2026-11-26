-- GameFixes.lua: the raid frames' container sized again after the interface was hidden (Alt-Z),
-- and the taskbar icon not flashing (a box in the game's options)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- the game's raid container: a layout sizes it 3000 x 3000, then (the next frame) to its frames
-- shown; none shown (the interface hidden): nonsense, as GetBounds gives then
local CV = { EnableBlinkApplicationIcon = "1" }
C_CVar = { GetCVar = function(n) return CV[n] end, SetCVar = function(n, v) CV[n] = tostring(v) end }
local c = CreateFrame("Frame", "CompactRaidFrameContainer", UIParent)
local refreshes, stuck = 0, false
function c:RefreshSize()
  refreshes = refreshes + 1
  if UIParent:IsVisible() then self:SetSize(300, 200) else self:SetSize(-100000, -100000) end
end
function c:LayoutFrames()
  self:SetSize(3000, 3000)
  if not stuck then C_Timer.After(0, function() self:RefreshSize() end) end
end
c:SetSize(300, 200)
c:Show()

local ns = {}
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3; S.energy = 100
ClaraComboPointsDB = { noBlink = "junk" }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
check(ns.sv.noBlink == nil, "broken saved value: back to the default (on)")
check(CV.EnableBlinkApplicationIcon == "0", "at login: the taskbar icon does not flash")

local function Size() local w, h = c:GetSize() return w .. "x" .. h end
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
M.timers = {}

-- interface shown: the game's own pass sizes it; nothing more
refreshes = 0
c:LayoutFrames(); Run()
check(Size() == "300x200" and refreshes == 1, "interface shown: the game sizes it, once (" .. Size() .. ", " .. refreshes .. ")")

-- Alt-Z: a raid update while hidden leaves it wrong; shown again, sized from its frames
UIParent:Hide()
refreshes = 0
c:LayoutFrames(); Run()
check(Size() ~= "300x200" and refreshes == 1, "interface hidden: the game's pass gets it wrong (" .. Size() .. ")")
UIParent:Show(); Run()
check(Size() == "300x200" and refreshes == 2, "interface shown again: sized from its frames (" .. Size() .. ")")

-- the game's pass not coming (its own flag stuck): sized after each layout anyway
stuck = true
c:LayoutFrames(); Run()
check(Size() == "300x200", "no pass of the game's: sized all the same (" .. Size() .. ")")

-- in combat: once out of it
S.inCombat = true
c:LayoutFrames(); Run()
check(Size() == "3000x3000", "in combat: left until it ends")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED"); Run()
check(Size() == "300x200", "out of combat: sized")

-- not in a group (hidden container): left alone
c:Hide()
c:SetSize(3000, 3000)
refreshes = 0
UIParent:Hide(); UIParent:Show(); Run()
check(refreshes == 0, "container hidden: not touched")
c:Show()
stuck = false

-- the box in the game's options
M.ShowSettingsPage(ns.settingsCategory)
local page = ns.settingsCategory and ns.settingsCategory.frame
check(page and page.noBlink, "a box in Esc > Options > AddOns > Clara")
if page and page.noBlink then
  local box = page.noBlink
  local text = (box.Text or box.text):GetText()
  check(box:GetChecked() and text:find("EnableBlinkApplicationIcon", 1, true), "ticked by default: " .. tostring(text))
  local who = page.whoHeader or page.whoNames -- (the /who boxes: the last of them)
  local _, _, _, _, y1 = who:GetPoint(1)
  local _, _, _, _, y2 = box:GetPoint(1)
  check(y2 == y1 - 24, "under the /who boxes")
  box:Click()
  check(ns.sv.noBlink == false and CV.EnableBlinkApplicationIcon == "1", "unticked: the icon flashes again")
  box:Click()
  check(ns.sv.noBlink == nil and CV.EnableBlinkApplicationIcon == "0", "ticked again: not flashing")
end
out("")
out(fails .. " failure(s)")
