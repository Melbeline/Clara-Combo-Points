-- Scenario tests for Clara Combo Points against the mock API.
local ADDON_DIR = ADDON_DIR
local M = MOCK
local S = M.state
local ns = {}
local print = function(s) io.write(tostring(s), "\n") end


local failures = 0
local function check(cond, msg)
  if cond then print("  ok   " .. msg) else failures = failures + 1; print("  FAIL " .. msg) end
end
local function cells() local t = {} for i = 1, 5 do t[i] = M.reveal(ns.hudCells[i]._value) end return t end

M.LoadAddon(ADDON_DIR, ns)

-- expose internals for checks
local hud = ns.hud
local bars, energyBar, energyText = {}, ns.powerBar, nil
for _, f in ipairs(M.frames) do
  if f._kind == "StatusBar" and f._parent == ns.comboRow then bars[#bars + 1] = f end
end
table.sort(bars, function(a, b) return a._min < b._min end)
ns.hudCells = bars
for _, r in ipairs(M.regions) do if r._kind == "FontString" and r._parent._parent == energyBar then energyText = r end end

print("== load")
M.Fire("ADDON_LOADED", "ClaraComboPoints")
check(ClaraComboPointsDB ~= nil and ClaraComboPointsDB.profiles.ROGUE.scale == 1 and ClaraComboPointsDB.profiles.DRUID.scale == 1, "saved variables created with a profile per class")
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD")
check(hud:IsShown(), "HUD shown for a rogue")
check(#bars == 5 and energyBar ~= nil, "5 combo cells + energy bar")
local c1 = bars[1]._barcolor
check(c1[1] == 1 and c1[2] == 1 and c1[3] == 0 and c1[4] == 1, "cell 1 is #FFFF00")
local e = energyBar._barcolor
check(e[1] == c1[1] and e[2] == c1[2] and e[3] == c1[3] and e[4] == c1[4], "energy bar same colour/opacity as cell 1")
check(energyText:GetFont() == "Fonts\\ARIALN.TTF", "default font Arial Narrow")

print("== size on a 2560x1440 windowed client (1359 px tall), any UI scale")
for _, ui in ipairs({ 0.64, 0.71, 1.0 }) do
  S.uiScale = ui; UIParent._scale = ui
  M.Fire("UI_SCALE_CHANGED")
  local l, b, w, h = M.AbsRect(hud) ; M.ResetLayout()
  local px = 1359 / 768 -- physical pixels per absolute unit
  local cl, cb, cw, ch = M.AbsRect(bars[1]); M.ResetLayout()
  local _, ecy = M.AbsRect(hud); M.ResetLayout()
  print(string.format("  ui %.2f -> HUD %.1f x %.1f px, cell %.1f x %.1f px, centre y %.1f px below screen centre",
    ui, w * px, h * px, cw * px, ch * px, (768 / 2) * px - (b + h / 2) * px))
  check(math.abs(w * px - 292) < 0.01, "width 292 px at ui scale " .. ui)
end

print("== energy regeneration (10/s, read every frame)")
S.energy = 40; M.Frame(0.016)
check(M.reveal(energyBar._value) == 40 and M.reveal(energyText._text) == 40, "energy 40 shown")
local updates = 0
local old = energyBar.SetValue
energyBar.SetValue = function(self, v, ...) updates = updates + 1; return old(self, v, ...) end
for i = 1, 60 do S.energy = 40 + i * 10 * 0.016; M.Frame(0.016) end -- one second at 60 fps
check(M.reveal(energyText._text) == math.floor(40 + 60 * 10 * 0.016), "energy follows regen frame by frame")
check(updates == 9, "only redrawn when the integer value changes (" .. updates .. " redraws for 9 points)")
energyBar.SetValue = old

print("== combo points follow the current target")
S.target = { cp = 0, hostile = true }; M.Fire("PLAYER_TARGET_CHANGED")
S.target.cp = 3; M.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
local v = cells(); check(v[1] == 3 and v[5] == 3, "3 points pushed to the 5 cells (cells 1-3 full, 4-5 empty)")
local A = S.target
S.target = nil; M.Fire("PLAYER_TARGET_CHANGED")
check(cells()[1] == 0, "deselect -> points disappear")
S.target = { cp = 0, hostile = true }; M.Fire("PLAYER_TARGET_CHANGED")
check(cells()[1] == 0, "other target without points -> 0")
S.target = A; M.Fire("PLAYER_TARGET_CHANGED")
check(cells()[1] == 3, "target A again -> 3 points back")
S.target = { cp = 0, hostile = false }; M.Fire("PLAYER_TARGET_CHANGED")
check(cells()[1] == 0, "friendly target -> 0")

print("== target death clears instantly")
S.target = A; M.Fire("PLAYER_TARGET_CHANGED")
A.dead = true -- server has not cleared the points yet: GetComboPoints still says 3
M.Fire("UNIT_HEALTH", "target")
check(cells()[1] == 0, "UNIT_HEALTH on death -> 0 although GetComboPoints still returns 3")
A.dead = false; A.feign = false
M.Fire("UNIT_HEALTH", "target")
check(cells()[1] == 3, "alive again (e.g. feign) -> points back")
A.dead, A.feign = true, true; M.Fire("UNIT_HEALTH", "target")
check(cells()[1] == 3, "feign death keeps the points")
A.dead, A.feign = false, false

print("== safety refresh without events")
A.cp = 5
M.Frame(0.05); M.Frame(0.06)
check(cells()[1] == 5, "missed event still picked up within 0.1 s")

print("== secret values")
S.secret = true
A.cp = 4; S.energy = 55
local ok, err = pcall(function()
  M.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
  M.Fire("UNIT_MAXPOWER", "player", "ENERGY")
  M.Frame(0.016); M.Frame(0.2)
  M.Fire("PLAYER_TARGET_CHANGED")
  M.Fire("UNIT_HEALTH", "target")
end)
check(ok, "no error with secret values " .. tostring(err))
check(issecretvalue(bars[1]._value) and M.reveal(bars[1]._value) == 4, "secret combo count passed straight to the bars")
check(issecretvalue(energyText._text) and M.reveal(energyText._text) == 55, "secret energy passed straight to the text")
ok, err = pcall(M.Fire, "UNIT_POWER_FREQUENT", "player", M.Secret("ENERGY"))
check(ok, "secret event payload handled " .. tostring(err))
S.target = nil; M.Fire("PLAYER_TARGET_CHANGED")
check(M.reveal(bars[1]._value) == 0, "deselect with secrets -> 0")
S.secret = false

print("== player source fallback")
ns:SetComboSource("PLAYER")
S.playerCP = 2; S.target = { cp = 0, hostile = true }; M.Fire("PLAYER_TARGET_CHANGED")
check(cells()[1] == 2, "PLAYER source reads UnitPower")
ns:SetComboSource("TARGET")
check(cells()[1] == 0, "back to TARGET source")
local gcp = GetComboPoints
GetComboPoints = function() error("restricted") end
M.Fire("PLAYER_TARGET_CHANGED")
check(cells()[1] == 2, "GetComboPoints error -> UnitPower fallback")
GetComboPoints = gcp

print("== options")
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
check(panel and panel:IsShown(), "/cl opens the options")
check(ns.preview == true and cells()[5] == 5, "preview shows 5 points while options are open")
-- click every button once (except reset-all which needs two clicks)
local clicked = 0
local pageButtons = {} -- the list of pages on the left
for _, f in ipairs(M.frames) do if f.page then pageButtons[#pageButtons + 1] = f end end
check(#pageButtons == 5 and ns.PAGE_COUNT == 5, "5 pages in the list on the left")
local okAll, errAll = pcall(function()
  for _, tab in ipairs(pageButtons) do
    tab:Click()
    for _, f in ipairs(M.frames) do
      if f._kind == "Button" and f:IsVisible() and f ~= panel and f._scripts and f._scripts.OnClick then
        local skip = f == panel.CloseButton or f.page
        if not skip then f:Click(); clicked = clicked + 1 end
        if ColorPickerFrame:IsShown() then M.PickerCancel() end
      end
    end
  end
end)
pageButtons[1]:Click()
for _, f in ipairs(M.frames) do if f.class == "ROGUE" then f:Click() end end -- back on the rogue tab
check(ns.profileClass == "ROGUE", "rogue tab selected again")
check(okAll, "clicked " .. clicked .. " buttons without error " .. tostring(errAll))
-- reset to known state
ns:ResetAll(); ns:SetPreview(true)
check(ns.db.font == "Arial Narrow", "reset all restores defaults")

-- scale input
ns:SetScalePercent(250); check(ns.db.scale == 2.5, "scale 250 %")
ns:SetScalePercent(9999); check(ns.db.scale == 5, "scale clamped to 500 %")
ns:SetScalePercent(1); check(ns.db.scale == 0.1, "scale clamped to 10 %")
SlashCmdList.CLARACOMBOPOINTS("scale 120"); check(ns.db.scale == 1.2, "/cl scale 120")
ns:SetScalePercent(100)

-- colour picker: stale alpha from a previous use must not leak in
M.SetStaleAlpha(0.1)
local function visibleSwatches()
  local t = {}
  for _, f in ipairs(M.frames) do if f._kind == "Button" and f._w == 34 and f:IsVisible() then t[#t + 1] = f end end
  return t
end
local function barRow(key) -- a bar in the Bars page's list
  for _, f in ipairs(M.frames) do if f.swatches and f.key == key and f:IsVisible() then return f end end
end
-- the colours are on the Bars page, each bar's under it (picked in the list); the value text
-- and the background of the bars on the General page
pageButtons[2]:Click()
local perBar = {}
for _, key in ipairs({ "combo", "power", "mana", "health" }) do
  local row = barRow(key)
  if row then row:Click(); perBar[key] = #visibleSwatches() end
end
pageButtons[1]:Click()
local generalSwatches = #visibleSwatches()
check(perBar.combo == 5 and perBar.power == 1 and perBar.health == 1 and perBar.mana == nil and generalSwatches == 2,
  string.format("9 colour swatches (health bar included): combo %s, energy %s, health %s, mana %s, general %d",
    tostring(perBar.combo), tostring(perBar.power), tostring(perBar.health), tostring(perBar.mana), generalSwatches))
pageButtons[2]:Click()
barRow("combo"):Click()
local swatches = visibleSwatches()
swatches[2]:Click()
check(ns.db.colors.cp2.a == 1, "opening the picker does not change the opacity")
M.PickColor(0.2, 0.4, 0.6, 0.5)
check(ns.db.colors.cp2.r == 0.2 and ns.db.colors.cp2.a == 0.5, "picker colour + opacity applied live")
check(bars[2]._barcolor[4] == 0.5, "cell 2 redrawn with new opacity")
M.PickerCancel()
check(ns.db.colors.cp2.r == 1 and ns.db.colors.cp2.a == 1, "cancel restores previous colour")
local cp2Slider = swatches[2]:GetParent().slider -- (its colour row's opacity)
barRow("power"):Click()
visibleSwatches()[1]:Click(); M.PickColor(0, 1, 0, 0.8); M.PickerOkay()
check(ns.db.colors.energy.g == 1 and ns.db.colors.energy.r == 0 and energyBar._barcolor[4] == 0.8, "energy colour set with Okay")

-- sliders
pageButtons[1]:Click()
local sliders = {}
for _, f in ipairs(M.frames) do if f._kind == "Slider" and f:IsVisible() and f:GetParent() ~= ClaraComboPointsOptions then sliders[#sliders + 1] = f end end
check(#sliders == 7, "general page: 7 sliders (scale, global, 2 out of combat, text size, value text and background opacities): " .. #sliders)
sliders[1]:SetValue(150); check(ns.db.scale == 1.5, "scale slider 150 %")
sliders[1].box:SetText("450"); sliders[1].box._scripts.OnEnterPressed(sliders[1].box)
check(ns.db.scale == 4.5 and sliders[1].box:GetText() == "450", "scale typed in the slider's box: 450 %")
ns:SetScalePercent(100)
check(sliders[1]:GetValue() == 100 and sliders[1].box:GetText() == "100", "scale slider follows /cl scale")
sliders[2]:SetValue(40); check(ns.db.alpha == 0.4 and hud._alpha == 0.4, "global opacity 40 %")
pageButtons[2]:Click(); barRow("combo"):Click()
check(cp2Slider:IsVisible(), "cell 2's opacity slider shown with the combo points bar")
cp2Slider:SetValue(25); check(ns.db.colors.cp2.a == 0.25 and bars[2]._barcolor[4] == 0.25, "cell 2 opacity 25 % on its own")
-- default colours: those of the bar picked only; all the bars: their sizes and every colour
local function visibleButton(text)
  for _, f in ipairs(M.frames) do if f._kind == "Button" and f:IsVisible() and f:GetText() == text then return f end end
end
local energyDefault = ns.defaults.colors.energy
barRow("power"):Click()
visibleButton(ns.L.DEFAULT_COLORS):Click()
local e2 = ns.db.colors.energy
check(e2.r == energyDefault.r and e2.g == energyDefault.g and e2.a == energyDefault.a and ns.db.colors.cp2.a == 0.25
  and energyBar._barcolor[4] == energyDefault.a, "default colors on the energy bar: energy back, cell 2 kept")
ns.db.bars.power.width, ns.db.bars.combo.height = 300, 30; ns:ApplyLayout()
visibleButton(ns.L.DEFAULT_ALL_BARS):Click()
check(ns.db.colors.cp2.a == 1 and bars[2]._barcolor[4] == 1 and ns.db.bars.power.width == ns.defaults.bars.power.width
  and ns.db.bars.combo.height == ns.defaults.bars.combo.height, "all bars to default: sizes and every colour")
pageButtons[1]:Click()
local sizeSlider
for _, f in ipairs(M.frames) do if f._kind == "Slider" and f:IsVisible() and f._min == 6 and f._max == 40 then sizeSlider = f end end
sizeSlider:SetValue(30); check(ns.db.fontSize == 30 and select(2, energyText:GetFont()) == 30, "font size 30")

-- fonts: a dropdown, the game's menu listing every font, each name drawn in its own font
local fontButton
for _, f in ipairs(M.frames) do
  if f._kind == "Button" and f:IsVisible() and f.text and f.Refresh and f.text._text == ns.db.font then fontButton = f end
end
check(fontButton ~= nil, "font dropdown shows the font in use")
M.Press(fontButton)
local emilyItem = M.MenuItem("Emily's Candy")
check(emilyItem ~= nil and emilyItem.kind == "radio", "Emily's Candy listed")
check(M.menu and type(M.menu.scrollExtent) == "number", "the font menu scrolls")
local probe = CreateFrame("Frame", nil, UIParent); probe:Hide()
local probeButton = { fontString = probe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") }
for _, fn in ipairs(emilyItem and emilyItem.initializers or {}) do fn(probeButton) end
check((probeButton.fontString:GetFont() or ""):find("EmilysCandy") ~= nil, "Emily's Candy drawn in its own font in the menu")
M.MenuPick("Emily's Candy")
check(energyText:GetFont():find("EmilysCandy") ~= nil, "Emily's Candy applied")
check(fontButton.text._text == "Emily's Candy" and fontButton.text:GetFont():find("EmilysCandy") ~= nil, "the dropdown shows Emily's Candy, in its font")
M.badFonts = { [ns:GetFontPath("Bangers")] = true }
ns.db.font = "Bangers"; ns:ApplyFont()
check(energyText:GetFont() == "Fonts\\ARIALN.TTF", "unloadable font falls back to Arial Narrow")
M.badFonts = nil
ns.db.font = "Arial Narrow"; ns:ApplyFont()

-- lock / drag
ns:SetLocked(false)
check(hud._mouse == true, "unlocked HUD takes the mouse")
hud:SetPoint("CENTER", UIParent, "CENTER", 100, 50) -- pretend it was dragged
hud._scripts.OnDragStop(hud)
print(string.format("  saved position %d, %d", ns.db.x, ns.db.y))
local savedX, savedY = ns.db.x, ns.db.y
ns:SetScalePercent(200)
local cx, cy = hud:GetCenter(); local hs = hud:GetEffectiveScale(); local ux, uy = UIParent:GetCenter(); local us = UIParent:GetEffectiveScale()
check(math.abs((cx * hs - ux * us) / (768 / 1359) - savedX) < 0.6, "scaling keeps the centre in place")
ns:SetScalePercent(100)
ns:SetLocked(true)
check(hud._mouse == false, "locked HUD is click-through")

-- combat turns preview off
S.target = { cp = 2, hostile = true }
M.Fire("PLAYER_REGEN_DISABLED")
check(ns.preview == false and cells()[1] == 2, "entering combat ends the preview")
panel:Hide()

print("== non-rogue stays dormant")
local nsBefore = ns

print(string.format("\n%d failure(s)", failures))
return failures
