local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function label(f) return (f._textFS and f._textFS._text) or (f.text and f.text._text) end
local function findButton(text)
  for _, f in ipairs(M.frames) do
    if (f._kind == "Button") and f:IsVisible() and label(f) == text then return f end
  end
end
-- class tabs: one row, each name wrapped in its class colour; found by their .class
local function tab(class)
  for _, f in ipairs(M.frames) do
    if f._kind == "Button" and f._template == "PanelTopTabButtonTemplate" and f.class == class and f:IsVisible() then return f end
  end
end
-- the list of pages on the left: each button knows its page (1 General ... 5 Profiles)
local function nav(i)
  for _, f in ipairs(M.frames) do
    if f._kind == "Button" and f.page == i and f.name and f.desc and f:IsVisible() then return f end
  end
end

local ns = {}
S.class = "ROGUE"; S.locale = "frFR"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local sv = ClaraComboPointsDB

out("== Classic sliders do not overlap the next colour row")
SlashCmdList.CLARACOMBOPOINTS("")
local function clickH(f) return (f._h or 0) - (f._hit and f._hit[3] or 0) - (f._hit and f._hit[4] or 0) end
local function visibleSliders()
  local t = {}
  for _, f in ipairs(M.frames) do
    if f._kind == "Slider" and f:IsVisible() and f._template == "UISliderTemplate" then t[#t + 1] = f end
  end
  return t
end
-- every page, and on the Bars page every bar of the class picked (its colour rows)
local worst, seen = 0, 0
local function measure()
  for _, f in ipairs(visibleSliders()) do
    seen = seen + 1
    local h = clickH(f)
    if h > worst then worst = h end
  end
end
for i = 1, 5 do nav(i):Click(); measure() end
nav(2):Click()
local barRows = {}
for _, f in ipairs(M.frames) do
  if f._kind == "Button" and f.key and f.show and f.swatches and f:IsVisible() then barRows[#barRows + 1] = f end
end
for _, r in ipairs(barRows) do r:Click(); measure() end
check(seen > 0 and worst > 0 and worst < 28, "slider click area " .. worst .. "px, less than the 28px row spacing (" .. seen .. " sliders, every page)")
-- combo points picked: its five colour rows, 28 apart; no slider's click area reaches the next one's
local comboRow
for _, r in ipairs(barRows) do if r.key == "combo" then comboRow = r end end
comboRow:Click()
local rowSliders = {}
for _, f in ipairs(visibleSliders()) do
  local holder = f:GetParent()
  if holder and holder.swatch and holder.on then rowSliders[#rowSliders + 1] = f end -- a colour row's slider
end
table.sort(rowSliders, function(a, b) local _, ab = M.Rect(a); local _, bb = M.Rect(b); return ab > bb end)
local overlap = false
for i = 2, #rowSliders do -- (in the sliders' own units, as their hit insets)
  local _, b1 = M.Rect(rowSliders[i - 1])
  local _, b2, _, h2 = M.Rect(rowSliders[i])
  local hitBottom1 = b1 + (rowSliders[i - 1]._hit and rowSliders[i - 1]._hit[4] or 0) -- inset < 0: area grows down
  local hitTop2 = b2 + h2 - (rowSliders[i]._hit and rowSliders[i]._hit[3] or 0)
  if hitTop2 > hitBottom1 + 0.01 then overlap = true end
end
check(#rowSliders == 5 and not overlap, "combo points: 5 colour rows, their sliders' click areas do not overlap (" .. #rowSliders .. " rows)")
nav(1):Click()

out("== scale box shows the value really applied")
local scaleSlider
for _, f in ipairs(visibleSliders()) do if f._min == ns.MIN_SCALE and f._max == ns.MAX_SCALE then scaleSlider = f end end
local box = scaleSlider and scaleSlider.box
check(box ~= nil and box:IsVisible(), "General page: the scale slider has its number box")
for _, typed in ipairs({ "999", "5", "" }) do
  box:SetFocus(); box:SetText(typed)
  box._scripts.OnEnterPressed(box)
  check(box:GetText() == tostring(ns:GetScalePercent()), ("typed '%s' + Enter -> box shows %s (scale %d %%)"):format(typed, box:GetText(), ns:GetScalePercent()))
end
-- (the Apply button is gone: Enter applies; leaving the box without Enter shows what is applied)
ns:SetScalePercent(120)
box:SetFocus(); box:SetText("777")
box:ClearFocus()
check(box:GetText() == "120" and ns:GetScalePercent() == 120, "typed 777, left the box without Enter: box back to the scale applied (120)")
box:SetFocus(); box:SetText("777")
box._scripts.OnEnterPressed(box)
check(box:GetText() == "500" and ns:GetScalePercent() == 500 and scaleSlider:GetValue() == 500, "777 + Enter -> 500, slider and box agree")
findButton("300%"):Click()
check(box:GetText() == "300" and ns:GetScalePercent() == 300 and scaleSlider:GetValue() == 300, "preset 300% -> slider and box show 300")
ns:SetScalePercent(100)
check(box:GetText() == "100" and scaleSlider:GetValue() == 100, "scale set elsewhere: box follows (100)")

out("== reset confirmation timers")
M.timers = {}
nav(5):Click()                      -- Profiles: the reset is there now
tab("DRUID"):Click()
local reset = findButton("Réinitialiser : Druide")
check(reset ~= nil, "Profiles page: reset button names the tab (Réinitialiser : Druide)")
reset:Click()                       -- arm #1 (timer #1)
tab("ROGUE"):Click()                -- disarmed by the tab switch
check(label(reset) == "Réinitialiser : Voleur", "tab switch disarms it and renames it (" .. tostring(label(reset)) .. ")")
tab("DRUID"):Click()
reset:Click()                       -- arm #2 (timer #2)
M.RunTimer(1)                       -- timer #1 fires
check(label(reset) == "Confirmer ?", "an older timer does not cancel a newer confirmation")
M.RunTimer(1)                       -- timer #2 fires
check(label(reset) == "Réinitialiser : Druide", "the confirmation still expires after its own 3 s")

out("== other class unlocked, then /reload with the window still open")
nav(1):Click()                      -- General: Position
findButton("Déverrouiller"):Click()
check(sv.profiles.DRUID.locked == false, "druid profile unlocked from the Druide tab")
M.Fire("PLAYER_LOGOUT")             -- the client saves variables without hiding the window first
check(sv.profiles.DRUID.locked == true, "relocked before the saved variables are written")
check(sv.profiles.ROGUE.locked == true, "this character's profile untouched")
ClaraComboPointsOptions:Hide()

out("== this character's own unlock survives a reload")
SlashCmdList.CLARACOMBOPOINTS("unlock")
M.Fire("PLAYER_LOGOUT")
check(sv.profiles.ROGUE.locked == false, "rogue stays unlocked (it is this character's bar)")
SlashCmdList.CLARACOMBOPOINTS("lock")

out(string.format("\n%d failure(s)", fails))
return fails
