-- every class of World of Warcraft: Forever (a mage here), the row of class tabs, the list of
-- pages (dragged), the class spells panel on the tab's class, the bar styles, a right-click off
-- the HUD, the icons' lock for all classes, hiding by hand, the portrait menu's options (game's
-- AddOns page and the options' Visibility page)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b, e) return a and b and math.abs(a - b) < (e or 0.01) end
local function label(f)
  if f.text and f.text._text then return f.text._text end
  if f._textFS then return f._textFS._text end
end
local function findButton(text)
  for _, f in ipairs(M.frames) do
    if (f._kind == "Button" or f._kind == "CheckButton") and f:IsVisible() and label(f) == text then return f end
  end
end
local function findCheck(text)
  for _, f in ipairs(M.frames) do
    if f._kind == "CheckButton" and f:IsVisible() and f.Text and f.Text._text == text then return f end
  end
end
local function rect(f) M.ResetLayout(); return M.AbsRect(f) end

local ns = {}
S.class = "MAGE"; S.locale = "frFR"; S.powerType = 0
S.mana, S.manaMax, S.health, S.healthMax = 1800, 3000, 900, 1500
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
M.Frame(0.016)
local L, sv = ns.L, ns.sv

out("== a mage")
check(ns.enabled and ns.homeClass == "MAGE" and ns.db == sv.profiles.MAGE, "the mage's own profile")
check(ns.hud:IsShown() and ns.manaBar:IsShown(), "the HUD shows the mana bar")
check(not ns.comboRow:IsShown() and not ns.powerBar:IsShown() and not ns.healthBar:IsShown(), "no combo points, no energy / rage, health off")
check(near(select(4, rect(ns.hud)) / ns.hud:GetEffectiveScale(), ns.db.bars.mana.height), "the HUD is just the mana bar")
for _, class in ipairs({ "PRIEST", "WARLOCK", "HUNTER", "SHAMAN", "PALADIN" }) do
  if type(sv.profiles[class]) ~= "table" or type(sv.profiles[class].bars) ~= "table" then check(false, "profile for " .. class) end
end
check(true, "a profile for every class")

out("== the options open on the mage's tab; one row of class tabs, the pages listed on the left")
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
local tabs = {}
for _, f in ipairs(M.frames) do if f.class and f.isTopTab then tabs[f.class] = f end end
local count = 0
for _ in pairs(tabs) do count = count + 1 end
check(count == 9, "nine class tabs (" .. count .. ")")
local function bottom(f) local _, b = rect(f); return b end
local function left(f) return (rect(f)) end
local function top(f) local _, b, _, h = rect(f); return b + h end
local CLASS_ORDER = { "PRIEST", "MAGE", "WARLOCK", "DRUID", "ROGUE", "HUNTER", "SHAMAN", "PALADIN", "WARRIOR" }
local oneRow, inOrder = true, true
for i = 2, #CLASS_ORDER do
  local t, prev = tabs[CLASS_ORDER[i]], tabs[CLASS_ORDER[i - 1]]
  if not near(bottom(t), bottom(tabs.PRIEST)) then oneRow = false end
  if not (left(t) > left(prev)) then inOrder = false end
end
check(oneRow, "Prêtre to Guerrier on one row")
check(inOrder, "the row in order")
local function plain(s) return s and (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
check(plain(label(tabs.DRUID)) == "Druide" and label(tabs.DRUID):find("|cffff7d0a", 1, true) ~= nil
  and plain(label(tabs.MAGE)) == "Mage", "each tab named in its class's colour (" .. tostring(label(tabs.DRUID)) .. ")")
local pl, pb, pw, ph = rect(panel)
local pr = pl + pw
-- the row's width as the game draws it: the mock's PanelTemplates_TabResize ignores its
-- absoluteSize (the common width the addon sets, t.fixedWidth) and its text measure counts the
-- |cffxxxxxx / |r escapes; so: each tab at the addon's common width, or its plain name + 20
local rowW = 0
for i, class in ipairs(CLASS_ORDER) do
  local t = tabs[class]
  local fs = t.Text
  local w = t.fixedWidth or math.max(70, MEASURE(fs._font and fs._font[1] or "OBJ", fs._font and fs._font[2] or 10, plain(fs._text)) + 20)
  rowW = rowW + w + (i > 1 and 4 or 0)
end
local s0 = panel:GetEffectiveScale()
check(left(tabs.PRIEST) - pl + rowW * s0 <= pw + 0.01, ("the row fits in the window (%d of %d)"):format(left(tabs.PRIEST) / s0 - pl / s0 + rowW, pw / s0))
-- the pages: a list on the left, under the class tabs
local navs = {}
for _, f in ipairs(M.frames) do
  if type(f.page) == "number" and not f.isTopTab and type(f.name) == "table" and f.name._kind == "FontString" and f.desc then navs[f.page] = f end
end
local PAGE_NAMES = { "Général", "Barres", "Icônes", "Visibilité", "Profils" }
local named = true
for i, name in ipairs(PAGE_NAMES) do
  local b = navs[i]
  if not (b and b:IsVisible() and b.name._text == name and type(b.desc._text) == "string" and b.desc._text ~= "") then named = false end
end
check(named and #navs == 5, "five pages listed, each with what it holds")
local stacked = true
for i = 2, 5 do if not (top(navs[i]) < top(navs[i - 1]) and near(left(navs[i]), left(navs[1]))) then stacked = false end end
check(stacked and table.concat(sv.pageOrder, ",") == "1,2,3,4,5", "one under the other, in order (" .. table.concat(sv.pageOrder, ",") .. ")")
local nl, _, nw = rect(navs[1])
check(top(navs[1]) <= bottom(tabs.PRIEST) + 0.01 and nl > pl and nl + nw <= pl + 168 * panel:GetEffectiveScale(),
  "the page list on the left, under the class tabs")
local flagFR
for _, f in ipairs(M.frames) do if f.lang == "frFR" and f.art then flagFR = f end end
local _, fb, _, fh = rect(flagFR)
check(fb + fh > pb + ph - 24 * panel:GetEffectiveScale(), "the flags in the title bar")
check(tabs.MAGE._selected ~= false, "Mage selected")
local footer
for _, r in ipairs(M.regions) do
  local t = r._kind == "FontString" and type(r._text) == "string" and r._text
  if t and t:find("Mage", 1, true) and t:find("personnage", 1, true) then footer = r end
end
check(footer and footer._parent:IsVisible() and left(footer) < pl + 168 * panel:GetEffectiveScale(), "this character uses: Mage (under the page list)")

out("== the mage's settings")
local function shownLabel(text)
  for _, r in ipairs(M.regions) do if r._kind == "FontString" and r._text == text and r._parent:IsVisible() then return true end end
end
local OTHER_COLORS = { "Point de combo 1", "Point de combo 5", "Barre d'énergie", "Barre de rage", "Rage à consommer" }
local function noOtherColor()
  for _, t in ipairs(OTHER_COLORS) do if shownLabel(t) then return false end end
  return true
end
local function barRows()
  local list = {}
  for _, f in ipairs(M.frames) do if f.swatches and f.key and f.show and f:IsVisible() then list[#list + 1] = f end end
  table.sort(list, function(a, b) return top(a) > top(b) end)
  return list
end
local function barRow(key) for _, row in ipairs(barRows()) do if row.key == key then return row end end end
navs[2]:Click() -- Barres
local listed = {}
for _, row in ipairs(barRows()) do listed[row.name._text] = row.key end
check(listed.Mana == "mana" and listed.Vie == "health" and not listed["Points de combo"] and not listed["Énergie"] and #barRows() == 2,
  "Bars page: mana and health")
-- the bar picked: its name over its settings, in the right column
local function pickedTitle(text)
  local row = barRows()[1]
  local rl, _, rw = rect(row)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text == text and r._parent:IsVisible() and left(r) > rl + rw then return r end
  end
end
local function rightSliders()
  local row = barRows()[1]
  local rl, _, rw = rect(row)
  local list = {}
  for _, f in ipairs(M.frames) do
    if f._kind == "Slider" and f:IsVisible() and f.box and left(f) > rl + rw and top(f) <= top(row) + 60 * panel:GetEffectiveScale() then list[#list + 1] = f end
  end
  table.sort(list, function(a, b) return top(a) > top(b) end)
  return list
end
check(pickedTitle("Mana") ~= nil, "the mana bar picked for its size")
check(rightSliders()[1] and rightSliders()[1]:GetValue() == ns.db.bars.mana.width, "its width on the first slider")
check(shownLabel("Barre de mana") and noOtherColor(), "its colour: mana; no combo, energy, rage colours")
barRow("health"):Click()
check(pickedTitle("Vie") ~= nil and shownLabel("Barre de vie") and noOtherColor(), "the health bar: its colour; no combo, energy, rage colours")
barRow("mana"):Click()
navs[1]:Click() -- Général: the value text and its colour
check(shownLabel("Afficher la valeur de mana") and shownLabel("Couleur") and shownLabel("Fond des barres (parties vides)"),
  "General page: value of mana, its colour, the bars' background")
check(noOtherColor(), "no combo, energy, rage colours there either")

out("== Bars page: every bar back to its default size and colours")
navs[2]:Click()
ns.db.bars.mana.width, ns.db.bars.health.height = 150, 40
ns.db.colors.mana = { r = .1, g = .9, b = .1, a = .5 }
ns:ApplyLayout()
ns:RefreshOptions()
local all = findButton("Toutes les barres par défaut")
check(all ~= nil, "a button for every bar's defaults")
all:Click()
check(ns.db.bars.mana.width == ns.defaults.bars.mana.width and ns.db.bars.health.height == ns.defaults.bars.health.height, "every bar back to its size")
local dm = ns.defaults.colors.mana
check(near(ns.db.colors.mana.r, dm.r) and near(ns.db.colors.mana.g, dm.g) and near(ns.db.colors.mana.a, dm.a), "and to its colours")
check(rightSliders()[1] and rightSliders()[1]:GetValue() == ns.defaults.bars.mana.width, "the slider shows it")

out("== pages dragged to a new place in the list")
local iconsNav, visNav = navs[3], navs[4]
iconsNav._scripts.OnDragStart(iconsNav)
local vl, vb, vw = rect(visNav)
M.cursorX, M.cursorY = vl + vw / 2, vb - 2 -- just under Visibilité, above the middle of Profils
iconsNav._scripts.OnUpdate(iconsNav, 0.016)
iconsNav._scripts.OnDragStop(iconsNav)
check(table.concat(sv.pageOrder, ",") == "1,2,4,3,5", "Icônes under Visibilité (" .. table.concat(sv.pageOrder, ",") .. ")")
check(top(iconsNav) < top(visNav) and top(visNav) < top(navs[2]) and top(navs[5]) < top(iconsNav), "drawn there")
iconsNav:Click() -- the button let go after the drag
check(navs[2].bg:IsShown() and not iconsNav.bg:IsShown(), "letting go after the drag opens nothing")
if iconsNav._scripts.OnMouseDown then iconsNav._scripts.OnMouseDown(iconsNav, "LeftButton") end -- a new press
iconsNav:Click()
check(iconsNav.bg:IsShown() and not navs[2].bg:IsShown() and shownLabel("Apparence des icônes"), "a click still opens the page")
panel:Hide()
SlashCmdList.CLARACOMBOPOINTS("")
check(top(navs[3]) < top(navs[4]) and table.concat(sv.pageOrder, ",") == "1,2,4,3,5", "the order is kept")

out("== the class spells panel opens on the tab's class")
local side = ClaraComboPointsSpells
local function open(class) for _, g in ipairs(side.groups) do if g.class == class then return g.rows ~= nil and #g.rows > 0 and g.rows[1]:IsShown() end end end
local function head(class) for _, g in ipairs(side.groups) do if g.class == class then return g.head end end end
tabs.PRIEST:Click()
navs[3]:Click()
check(side:IsShown() and open("PRIEST") and not open("ROGUE"), "Priest unfolded on the Priest tab")
tabs.WARRIOR:Click()
check(open("WARRIOR") and not open("PRIEST"), "the Warrior tab: Warrior unfolded, Priest folded")
local scroll = ClaraComboPointsSpellsScroll
local _, hb, _, hh = rect(head("WARRIOR"))
local _, sb, _, sh = rect(scroll)
local maxScroll = math.max(0, ClaraComboPointsSpells.groups and (function()
  local child = scroll:GetScrollChild(); return child:GetHeight() - scroll:GetHeight() end)() or 0)
check(hb >= sb - 1 and hb + hh <= sb + sh + 1 and (scroll:GetVerticalScroll() > 0 or maxScroll <= 0),
  "the warriors' heading in view (scroll " .. scroll:GetVerticalScroll() .. ")")
tabs.MAGE:Click()
panel:Hide()

out("== bar styles")
local war = sv.profiles.WARRIOR
check(near(war.colors.rage.r, .663), "flat: the addon's rage colour")
SlashCmdList.CLARACOMBOPOINTS("")
tabs.WARRIOR:Click()
ns.db.colors.energy = { r = .2, g = .3, b = .4, a = 1 }
ns:SetSkin("CLASSIC")
check(ns.db.skin == "CLASSIC" and ns.powerBar._bartex == "Interface\\TargetingFrame\\UI-StatusBar", "Classic: the game's shaded bars")
check(war.colors.rage.r == 1 and war.colors.rage.g == 0, "the game's rage red")
check(near(ns.db.colors.energy.r, .2), "a colour the player chose stays")
local frame = ns.powerBar.skins and ns.powerBar.skins.CLASSIC
check(frame and frame:IsShown() and frame:GetFrameLevel() < ns.powerBar:GetFrameLevel(), "a frame under the bar")
local fl, fb2, fw, fh2 = rect(frame)
local bl, bb, bw, bh = rect(ns.powerBar)
check(fl < bl and fb2 < bb and fl + fw > bl + bw and fb2 + fh2 > bb + bh, "around it")
ns:SetSkin("TOOLTIP")
check(ns.powerBar.skins.TOOLTIP:IsShown() and not ns.powerBar.skins.CLASSIC:IsShown(), "Tooltip: its own frame")
ns:SetSkin("FLAT")
check(near(war.colors.rage.r, .663) and ns.powerBar._bartex == "Interface\\Buttons\\WHITE8X8", "flat again: the addon's rage, plain bars")
check(not ns.powerBar.skins.TOOLTIP:IsShown(), "no frame")
tabs.MAGE:Click()
panel:Hide()
-- a rogue's HUD in the Classic style: no frame over another
local rogue = sv.profiles.ROGUE
rogue.bars.health.show = true
SlashCmdList.CLARACOMBOPOINTS("")
tabs.ROGUE:Click()
ns:SetSkin("CLASSIC")
M.Frame(0.016)
local cells = {}
for _, f in ipairs(M.frames) do if f._parent == ns.comboRow and f._kind == "StatusBar" then cells[#cells + 1] = f end end
local overlap = false
local framesList = { ns.powerBar.skins.CLASSIC, ns.healthBar.skins.CLASSIC }
for i = 1, 5 do framesList[#framesList + 1] = cells[i].skins.CLASSIC end
for i = 1, #framesList do
  for j = i + 1, #framesList do
    local al, ab, aw, ah = rect(framesList[i]); local cl, cb, cw, ch = rect(framesList[j])
    if al < cl + cw - 0.01 and cl < al + aw - 0.01 and ab < cb + ch - 0.01 and cb < ab + ah - 0.01 then overlap = true end
  end
end
check(not overlap, "Classic: no frame over another (bars, combo cells)")
ns:SetSkin("FLAT")
tabs.MAGE:Click()
panel:Hide()

out("== HUD icons: a right-click takes one off; one lock for every class")
ns.db.rows.above[1] = { 6774, 1943 }
ns:SetIconsLocked(false)
local allOpen = true
for _, profile in pairs(sv.profiles) do if profile.iconsLocked ~= false then allOpen = false end end
check(allOpen, "unlocked: every class")
M.Frame(0.016)
local row
for _, f in ipairs(M.frames) do if f.slots and f.side == "above" and f.k == 1 then row = f end end
local slot = row.slots[1]
local logged = #M.log
slot._scripts.OnMouseUp(slot, "RightButton")
check(#ns.db.rows.above[1] == 1 and ns:EntrySpell(ns.db.rows.above[1][1]) == 1943, "right-click: the icon is gone")
check(#M.log == logged, "and nothing in the chat")
SlashCmdList.CLARACOMBOPOINTS("")
tabs.WARRIOR:Click()
panel:Hide()
check(sv.profiles.WARRIOR.iconsLocked == false, "closing the options keeps the icons' lock as it is, for every class")
ns:SetIconsLocked(true)

out("== hidden by hand: this character's choice")
SlashCmdList.CLARACOMBOPOINTS("")
tabs.WARRIOR:Click()
SlashCmdList.CLARACOMBOPOINTS("hide")
check(sv.profiles.MAGE.hidden == true and sv.profiles.WARRIOR.hidden == false, "/cl hide on the Warrior tab hides the mage's HUD, not the warriors'")
panel:Hide()
check(not ns.hud:IsShown(), "hidden")
SlashCmdList.CLARACOMBOPOINTS("show")
check(ns.hud:IsShown() and sv.profiles.MAGE.hidden == false, "/cl show")

out("== shown by hand against a situation")
S.group = nil
ns.db.hideWhen.solo = true
M.Fire("GROUP_ROSTER_UPDATE")
check(not ns.hud:IsShown() and not ns:ShownByChoice(), "not in a group: hidden by the rule")
SlashCmdList.CLARACOMBOPOINTS("show")
check(ns.hud:IsShown() and ns:ShownByChoice(), "/cl show shows it anyway")
M.OpenUnitMenu("SELF")
local line
for _, f in ipairs(M.frames) do if f.slider and f.check and f.label then line = f end end
check(line.check:GetChecked() == true, "the portrait's box is ticked")
M.CloseUnitMenu()
S.group = "party"; M.Fire("GROUP_ROSTER_UPDATE")
S.group = nil; M.Fire("GROUP_ROSTER_UPDATE")
check(not ns.hud:IsShown(), "the situation changed and came back: the rule again")
M.OpenUnitMenu("SELF")
check(line.check:GetChecked() == false, "the box says so")
line.check:Click()
check(ns.hud:IsShown(), "one click on the box shows it")
M.CloseUnitMenu()
ns.db.hideWhen.solo = false
ns:UpdateVisibility()

out("== the game's options: the portrait menu's parts")
M.ShowSettingsPage(M.settingsCategories[1])
local lineBox = findCheck("Section Clara Combo Points (opacité, affichage, icônes verrouillées)")
local reloadBox = findCheck("Recharger l'interface")
check(lineBox and reloadBox and lineBox:GetChecked() and reloadBox:GetChecked(), "two boxes, ticked")
lineBox:Click()
check(sv.menu.line == false, "the section off")
M.OpenUnitMenu("SELF")
check(not table.concat(M.UnitMenuTexts(), "|"):find("Clara", 1, true), "not in the menu")
M.CloseUnitMenu()
lineBox:Click()
check(sv.menu.line == true, "back on")

out("== the options' Visibility page: the same two boxes")
local function inside(f, root) while f do if f == root then return true end f = f._parent end end
local function panelCheck(text)
  for _, f in ipairs(M.frames) do
    if f._kind == "CheckButton" and f:IsVisible() and f.Text and f.Text._text == text and inside(f, panel) then return f end
  end
end
SlashCmdList.CLARACOMBOPOINTS("")
navs[4]:Click()
local optLine, optReload = panelCheck("Section Clara Combo Points"), panelCheck("Recharger l'interface")
check(optLine and optReload and optLine:GetChecked() and optReload:GetChecked(), "two boxes on the Visibility page, ticked")
optLine:Click()
check(sv.menu.line == false and not lineBox:GetChecked(), "the section off; the game's AddOns page says so")
M.OpenUnitMenu("SELF")
check(not table.concat(M.UnitMenuTexts(), "|"):find("Clara", 1, true), "not in the menu")
M.CloseUnitMenu()
reloadBox:Click()
check(sv.menu.reload == false and not optReload:GetChecked(), "Reload UI off on the game's page: the options' box follows")
M.OpenUnitMenu("SELF")
check(not table.concat(M.UnitMenuTexts(), "|"):find("Recharger l'interface", 1, true), "no Reload UI in the menu")
M.CloseUnitMenu()
optLine:Click(); optReload:Click()
check(sv.menu.line == true and sv.menu.reload == true and lineBox:GetChecked() and reloadBox:GetChecked(), "both back on, both pages agree")
M.OpenUnitMenu("SELF")
local menuText = table.concat(M.UnitMenuTexts(), "|")
check(menuText:find("Clara", 1, true) and menuText:find("Recharger l'interface", 1, true), "back in the menu")
M.CloseUnitMenu()
panel:Hide()

out(("\n%d failure(s)"):format(fails))
return fails
