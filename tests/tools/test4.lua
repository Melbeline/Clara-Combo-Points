local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local function label(f)
  local t
  if f.text and f.text._text then t = f.text._text elseif f._textFS then t = f._textFS._text end
  if type(t) == "string" then t = (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end -- class tabs: names in class colours
  return t
end
local function findButton(text)
  for _, f in ipairs(M.frames) do
    if (f._kind == "Button" or f._kind == "CheckButton") and f:IsVisible() and label(f) == text then return f end
  end
end
local function findCheck(text)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text == text then
      local f = r._parent
      if f:IsVisible() then return f end
    end
  end
end
local function active(b)
  if b.page and b.bg then return b.bg:IsShown() end -- a page of the list on the left: lit
  if b._template == "PanelTopTabButtonTemplate" or b._template == "PanelTabButtonTemplate" then return b._selected == true end
  if b._template == "UIPanelButtonTemplate" then return b._locked == true end
  return b.flat and b.flat._color and b.flat._color[1] > .3
end
local function allTexts()
  local t = {}
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text and r._parent:IsVisible() then t[tostring(r._text)] = true end
  end
  return t
end
local function navName(b) return b.name and b.name._text end
-- Bars page: the bars in the list (click one: its settings on the right), the colour rows shown
local function barRow(key)
  for _, f in ipairs(M.frames) do if f.swatches and f.key == key and f:IsVisible() then return f end end
end
local function barKeys()
  local t = {}
  for _, f in ipairs(M.frames) do if f.swatches and f:IsVisible() then t[#t + 1] = f.key end end
  return t
end
local function pick(key) local row = barRow(key); if row then row:Click() end return row end
local function colorRow(text)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text == text and r._parent.swatch and r._parent.label == r and r._parent:IsVisible() then return r._parent end
  end
end
local function colorLabels(into)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text and r._parent.swatch and r._parent.label == r and r._parent:IsVisible() then into[r._text] = true end
  end
  return into
end
local function fontDropdown(current) -- General page: the button showing the font in use
  for _, f in ipairs(M.frames) do
    if f._kind == "Button" and f:IsVisible() and f.text and f.Refresh and f.text._text == current then return f end
  end
end

local ns = {}
S.class = "ROGUE"; S.locale = "frFR"
M.LoadAddon(ADDON_DIR, ns)

out("== migration from 1.1, and damaged saved variables")
ClaraComboPointsDB = { scale = 1.5, x = 10, y = -100, font = "Bangers", druidCatOnly = false, junk = "x",
  colors = { cp1 = { r = 1, g = 0, b = 0, a = .5 } } }
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local sv = ClaraComboPointsDB
check(sv.profiles and sv.scale == nil and sv.colors == nil, "flat settings moved into profiles")
for _, class in ipairs({ "ROGUE", "DRUID" }) do
  local p = sv.profiles[class]
  check(p.scale == 1.5 and p.x == 10 and p.font == "Bangers" and p.colors.cp1.a == .5 and p.colors.cp2.g == .808 and p.junk == nil,
    class .. " profile keeps the old settings, no stray keys")
end
check(sv.skin == nil and sv.language == nil and ns.lang == "frFR", "no theme setting any more, language follows the client")
check(type(sv.profiles.WARRIOR) == "table" and sv.profiles.WARRIOR.scale == 1 and sv.profiles.WARRIOR.y == -218,
  "warrior profile created fresh (warriors never had 1.1 settings)")
check(#sv.profiles.WARRIOR.rows.above[1] == 5 and #sv.profiles.ROGUE.rows.above[1] == 0, "default icon row for warriors only")
do
  local ns2 = {}
  M.eventFrames = {}
  M.LoadAddon(ADDON_DIR, ns2)
  ClaraComboPointsDB = { profiles = "junk", language = "deDE", skin = "MODERN" }
  M.Fire("ADDON_LOADED", "ClaraComboPoints")
  local d = ClaraComboPointsDB
  check(type(d.profiles.ROGUE) == "table" and d.language == "deDE" and d.skin == nil and d.profiles.ROGUE.language == nil,
    "'profiles' not a table: rebuilt, language kept at account level, old theme dropped")
  ClaraComboPointsDB = { profiles = { ROGUE = { rows = { above = { { 7386, "x", -3, 1.5, {}, "" }, "bad" }, below = 5 } } } }
  M.eventFrames = {}; M.LoadAddon(ADDON_DIR, {})
  M.Fire("ADDON_LOADED", "ClaraComboPoints")
  local r = ClaraComboPointsDB.profiles.ROGUE.rows
  check(#r.above[1] == 2 and r.above[1][1] == 7386 and r.above[1][2] == "x" and #r.above[2] == 0 and #r.below[3] == 0,
    "damaged icon rows cleaned (bad entries dropped, missing rows rebuilt)")
  local big = {}
  for i = 1, 30 do big[i] = i end
  ClaraComboPointsDB = { profiles = { ROGUE = { rows = { above = { big } } } } }
  M.eventFrames = {}; M.LoadAddon(ADDON_DIR, {})
  M.Fire("ADDON_LOADED", "ClaraComboPoints")
  check(#ClaraComboPointsDB.profiles.ROGUE.rows.above[1] == 20, "rows capped at 20 icons")
  ClaraComboPointsDB = sv
  M.eventFrames = {}
end
-- reload the real addon state
ns = {}
M.eventFrames = {}
M.LoadAddon(ADDON_DIR, ns)
ClaraComboPointsDB = sv
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")

local hud = ns.hud
local bars = {}
for _, f in ipairs(M.frames) do if f._kind == "StatusBar" and f._parent == ns.comboRow then bars[#bars + 1] = f end end
table.sort(bars, function(a, b) return a._min < b._min end)

out("== options window")
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
check(panel and panel:IsShown(), "window opens")
local classique = findButton("Classique")
check(ClaraComboPointsOptionsClassic == nil and not findButton("Moderne") and (not classique or classique.skin == "CLASSIC"),
  "one look only: no theme buttons (Classique is the bars' style)")
check(panel._template == "PortraitFrameTemplate" and panel.PortraitContainer.portrait._file == "Interface\\Icons\\Ability_Rogue_Eviscerate",
  "Blizzard portrait frame, Eviscerate icon on the Voleur tab")
check(findButton("Déverrouiller")._template == "UIPanelButtonTemplate", "Blizzard red buttons")
local function groups() local n = 0 for _, f in ipairs(M.frames) do if M.IsGroupBox(f) and f:IsVisible() then n = n + 1 end end return n end
check(groups() == 3, "general page: settings in 3 bordered groups (scale, opacity, look), like the character sheet (" .. groups() .. ")")
check(panel.Bg._vc and panel.Bg._vc[1] < .4, "darker window background")
local pageTabs = {} -- the list of pages on the left
for _, f in ipairs(M.frames) do if f.page then pageTabs[#pageTabs + 1] = f end end
do
  local names = {}
  for i, b in ipairs(pageTabs) do names[i] = tostring(navName(b)) end
  check(#pageTabs == 5 and names[1] == "Général" and names[2] == "Barres" and names[3] == "Icônes" and names[4] == "Visibilité"
    and names[5] == "Profils", "pages Général / Barres / Icônes / Visibilité / Profils (" .. table.concat(names, " / ") .. ")")
  local described = #pageTabs == 5
  for _, b in ipairs(pageTabs) do if not (b.desc and b.desc._text and b.desc._text ~= "" and b.desc:IsVisible()) then described = false end end
  check(described and pageTabs[2].desc._text == "Ordre, taille et couleurs de chaque barre", "each page with a line saying what it holds")
end
check(active(pageTabs[1]) and not active(pageTabs[2]), "opens on the first page")
do
  local function r(f) M.ResetLayout(); local l, b, w, h = M.Rect(f); return l, l + w, b + h, b end -- left, right, top, bottom
  local pl, pr, pt, pb = r(panel)
  check(math.abs((pr - pl) - 910) < 0.5 and math.abs((pt - pb) - 720) < 0.5, "window 910 x 720 (" .. (pr - pl) .. " x " .. (pt - pb) .. ")")
  local tabs = {}
  for _, f in ipairs(M.frames) do if f.class and f._template == "PanelTopTabButtonTemplate" then tabs[#tabs + 1] = f end end
  local oneRow, order, prevRight = true, {}, nil
  local _, _, firstTop, firstBottom = r(tabs[1])
  for i, t in ipairs(tabs) do
    local l, right, top = r(t)
    order[i] = t.class
    if math.abs(top - firstTop) > 0.5 or (prevRight and l < prevRight) then oneRow = false end
    prevRight = right
  end
  check(#tabs == 9 and oneRow and table.concat(order, " ") == "PRIEST MAGE WARLOCK DRUID ROGUE HUNTER SHAMAN PALADIN WARRIOR",
    "top row: the 9 class tabs in one row, left to right")
  -- each tab after the one before it; the row as wide as the game makes the tabs: the width the
  -- addon gives them all (fixedWidth), else their text + 20 (at least 70). (The mock's
  -- PanelTemplates_TabResize ignores that width, and its text widths count the colour escapes.)
  local chained = true
  for i = 2, #tabs do
    local point, rel, relPoint, x = tabs[i]:GetPoint(1)
    if not (point == "LEFT" and rel == tabs[i - 1] and relPoint == "RIGHT" and x == 4) then chained = false end
  end
  local rowRight = r(tabs[1])
  for i, t in ipairs(tabs) do
    local w = t.fixedWidth
    if not w then
      local text = (t.Text._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
      w = math.max(70, MEASURE(t.Text._font[1], t.Text._font[2], text) + 20)
    end
    rowRight = rowRight + w + (i > 1 and 4 or 0)
  end
  check(chained and rowRight <= pr - 10, "the class tabs fit in the window (" .. math.floor(pr - rowRight) .. " px to spare)")
  local lastFlag, flagsAbove = nil, true
  for _, f in ipairs(M.frames) do
    if f.lang then
      lastFlag = f
      local _, _, _, fb = r(f)
      if fb < firstTop then flagsAbove = false end
    end
  end
  local _, fRight = r(lastFlag)
  check(flagsAbove and fRight <= pr - 10 and fRight >= pr - 40, "the flags in the title bar, above the tabs, at its right end (" .. math.floor(pr - fRight) .. " px to spare)")
  -- the list of pages on the left, under the tabs, then the preview, then the character's class
  local nav = pageTabs[1]:GetParent()
  local nl, nr, nt, nb = r(nav)
  local inList, prevBottom = true, nil
  for _, i in ipairs(ns.sv.pageOrder) do
    local l, right, top, bottom = r(pageTabs[i])
    if l < nl or right > nr or top > nt or (prevBottom and top > prevBottom + 0.5) then inList = false end
    prevBottom = bottom
  end
  check(nt <= firstBottom and nl >= pl and inList, "the pages listed on the left, under the class tabs, top to bottom")
  local preview = findButton("Aperçu (tout allumé)")
  local vl, vr, vt, vb = r(preview)
  local previewHint
  for _, rg in ipairs(M.regions) do if rg._kind == "FontString" and rg._text == "se coupe en combat" and rg:IsVisible() then previewHint = rg end end
  local _, _, pht, phb = r(previewHint)
  check(preview and preview:GetParent() == nav and vt <= prevBottom and vl >= nl and vr <= nr and previewHint and pht <= vb,
    "the preview button and its hint under the list of pages")
  local whoFS
  for _, rg in ipairs(M.regions) do if rg._kind == "FontString" and rg._text == "Ce personnage utilise : Voleur" then whoFS = rg end end
  local hl, hr, ht, hb = r(whoFS)
  check(whoFS and whoFS:IsVisible() and hb >= nb and hl >= nl and hr <= nr + 0.5 and ht < phb, "'this character uses' at the bottom of the list")
  -- the page beside the list: its groups right of the list, under the tabs, in the window
  local gl, gr, gt = math.huge, -math.huge, -math.huge
  for _, f in ipairs(M.frames) do
    if M.IsGroupBox(f) and f:IsVisible() then
      local l, right, top = r(f)
      gl, gr, gt = math.min(gl, l), math.max(gr, right), math.max(gt, top)
    end
  end
  check(gl >= nr and gr <= pr - 10 and gt <= firstBottom, "the page shown right of the list, under the tabs")
  -- the window's opacity at the bottom right, in the footer
  local opacity
  for _, f in ipairs(M.frames) do if f._kind == "Slider" and f:GetParent() == panel then opacity = f end end
  local ol, oright, ot, ob = r(opacity)
  local obl, obr = r(opacity.box.holder)
  local labelFS
  for _, rg in ipairs(M.regions) do if rg._kind == "FontString" and rg._text == "Opacité des fenêtres" and rg._parent == panel then labelFS = rg end end
  local ll, lr = r(labelFS)
  check(opacity and opacity._w == 90 and obr <= pr - 20 and ob >= pb and ot <= pb + 40 and labelFS and lr <= ol and ol > (pl + pr) / 2,
    "window opacity at the bottom right: label, slider (90) and box")
end
local rogueTab, druidTab, warriorTab = findButton("Voleur"), findButton("Druide"), findButton("Guerrier")
check(rogueTab and druidTab and warriorTab, "Voleur, Druide and Guerrier tabs")
check(rogueTab.class == "ROGUE" and rogueTab.Text._text == "|cfffff569Voleur|r" and druidTab.Text._text == "|cffff7d0aDruide|r",
  "class names in their class colours (" .. tostring(rogueTab.Text._text) .. ")")
check(active(rogueTab) and not active(druidTab) and ns.db == sv.profiles.ROGUE, "opens on this character's tab")
pageTabs[4]:Click() -- Visibility
check(groups() == 3, "visibility page: display, portrait's menu and hiding groups (" .. groups() .. ")")
check(not findCheck("Afficher seulement en forme de félin et d'ours"), "Cat/Bear Form option hidden on the Voleur tab")
pageTabs[2]:Click() -- Bars
check(groups() == 2, "bars page: the list of bars and the bar picked (" .. groups() .. ")")
pick("power")
check(not colorRow("Rage à consommer"), "rage prediction hidden on the Voleur tab")
check(colorRow("Barre d'énergie") and not colorRow("Barre d'énergie").on:IsVisible() and not colorRow("Barre de rage"),
  "Voleur energy bar: its colour without a box (the list's box switches it), no rage")
pick("combo")
check(findButton("la cible (conseillé)") ~= nil, "combo source shown on the Voleur tab")
druidTab:Click()
check(ns.db == sv.profiles.DRUID and active(druidTab) and not active(rogueTab), "Druide tab edits the druid profile")
pick("power")
local cost = colorRow("Rage à consommer")
local costBoxed = cost ~= nil and cost.on:IsVisible()
pageTabs[4]:Click()
check(findCheck("Afficher seulement en forme de félin et d'ours") ~= nil and costBoxed,
  "Cat/Bear Form option and rage prediction (the box of the rage to spend) shown on the Druide tab")
pageTabs[2]:Click()
do -- the cost colour's box is the prediction switch
  local was = ns.db.predict
  cost = colorRow("Rage à consommer")
  cost.on.check:Click()
  local flipped = ns.db.predict == not was and cost.on.check:GetChecked() == not was
  cost.on.check:Click()
  check(flipped and ns.db.predict == was, "the rage to spend's box turns the prediction on and off")
end
do -- each bar's colours under it: a box per part if the bar has several (the druid's energy and
   -- rage, the combo cells); a bar of one part is switched by its box in the list
  local function boxedRow(text) -- nil: no such row shown; else whether it has its box
    local row = colorRow(text)
    if row then return row.on:IsShown() end
  end
  pick("power")
  local energy, rage = boxedRow("Barre d'énergie"), boxedRow("Barre de rage")
  pick("mana")
  local mana = boxedRow("Barre de mana")
  pick("health")
  local health = boxedRow("Barre de vie")
  local classColor = findCheck("Vie à la couleur de la classe")
  check(energy == true and rage == true and mana == false and health == false and classColor ~= nil,
    "Druide bars: energy and rage each with a box, mana and health without, health in the class colour ("
    .. table.concat({ tostring(energy), tostring(rage), tostring(mana), tostring(health), tostring(classColor ~= nil) }, " ") .. ")")
  pick("combo")
  local boxed = 0
  for i = 1, 5 do local row = colorRow("Point de combo " .. i); if row and row.on:IsShown() then boxed = boxed + 1 end end
  check(boxed == 5 and findButton("la cible (conseillé)") ~= nil, "Druide combo points: 5 colours each with a box, and where the points are read")
  -- the box of a bar in the list: the whole bar
  local combo = barRow("combo")
  combo.show.check:Click()
  local off = not ns:BarOn("combo")
  for i = 1, 5 do if not ns.db.disabled["cp" .. i] then off = false end end
  combo.show.check:Click()
  local on = ns:BarOn("combo")
  for i = 1, 5 do if ns.db.disabled["cp" .. i] then on = false end end
  local manaRow, wasMana = barRow("mana"), ns.db.bars.mana.show
  manaRow.show.check:Click()
  local manaFlipped = ns.db.bars.mana.show == not wasMana and manaRow.show.check:GetChecked() == not wasMana
  manaRow.show.check:Click()
  check(off and on and manaFlipped and ns.db.bars.mana.show == wasMana, "a bar's box in the list turns the whole bar off and on (5 combo cells, mana bar)")
end
check(panel.PortraitContainer.portrait._file == "Interface\\Icons\\Ability_Druid_CatForm", "Cat Form icon on the Druide tab")
warriorTab:Click()
do
  local noCombo = barRow("combo") == nil
  local sourceSeen = false
  for _, key in ipairs(barKeys()) do
    pick(key)
    if findButton("la cible (conseillé)") then sourceSeen = true end
  end
  pick("power")
  local wcost = colorRow("Rage à consommer")
  local wcostBoxed = wcost ~= nil and wcost.on:IsVisible()
  pageTabs[4]:Click()
  check(ns.db == sv.profiles.WARRIOR and wcostBoxed and noCombo and not sourceSeen
    and not findCheck("Afficher seulement en forme de félin et d'ours"), "Guerrier tab: rage prediction, no combo source, no forms")
end
pageTabs[1]:Click()
check(findCheck("Afficher la valeur de rage") ~= nil, "Guerrier tab: 'show rage value'")
check(panel.PortraitContainer.portrait._file == "Interface\\Icons\\Ability_Warrior_BattleShout", "Battle Shout icon on the Guerrier tab")
-- colours: each bar's on the Bars page (the bar picked in the list), the value text's and the
-- bars' background on the General page
local function classColors()
  local t = colorLabels({})
  pageTabs[2]:Click()
  for _, key in ipairs(barKeys()) do
    pick(key)
    colorLabels(t)
  end
  pageTabs[1]:Click()
  return t
end
local t = classColors()
check(not t["Point de combo 1"] and t["Barre de rage"] and t["Rage à consommer"] and t["Fond des barres (parties vides)"] and not t["Barre d'énergie"]
  and t["Couleur"] and findCheck("Afficher la valeur de rage"),
  "Guerrier colours: rage, rage to spend, bar background, value; no combo points, no energy")
druidTab:Click()
t = classColors()
check(t["Point de combo 1"] and t["Barre de rage"] and t["Barre d'énergie"] and findCheck("Afficher la valeur énergie / rage"), "Druide colours: combo points, energy and rage")
pageTabs[5]:Click() -- Profiles

-- reset confirmation does not follow a tab switch
local reset = findButton("Réinitialiser : Druide")
check(reset ~= nil, "reset button named after the tab, on the Profiles page")
reset:Click()
check(findButton("Confirmer ?") == reset, "reset asks for confirmation")
findButton("Voleur"):Click()
check(findButton("Réinitialiser : Voleur") == reset, "switching tab disarms the reset")
findButton("Druide"):Click()
pageTabs[1]:Click()

-- unlock on the other class's tab does not stay behind
findButton("Déverrouiller"):Click()
check(sv.profiles.DRUID.locked == false and hud._mouse == true, "druid profile unlocked from the Druide tab")
-- a drag that ends after the profile changed goes back to its own profile
hud._scripts.OnDragStart(hud)
panel:Hide()
check(ns.db == sv.profiles.ROGUE, "closing returns to this character's profile")
hud:SetPoint("CENTER", UIParent, "CENTER", 300, 300)
local rx, ry = sv.profiles.ROGUE.x, sv.profiles.ROGUE.y
hud._scripts.OnDragStop(hud)
check(sv.profiles.ROGUE.x == rx and sv.profiles.ROGUE.y == ry, "drag interrupted by the profile switch is not saved into the rogue profile")
check(sv.profiles.DRUID.locked == true, "druid profile locked again when the window closed")
ns.db.locked = true; ns:SetLocked(true)
SlashCmdList.CLARACOMBOPOINTS("")
findButton("Druide"):Click()

out("== languages")
local flags = {}
for _, f in ipairs(M.frames) do if f.lang and f:IsVisible() then flags[f.lang] = f end end
flags.deDE:Click()
local t = allTexts()
local german = ns.lang == "deDE" and findButton("Schurke") and findButton("Druide") and findButton("Krieger") and findButton("Standardposition")
  and t["Skalierung"] and t["Leistenhintergrund (leerer Teil)"] and t["Energie-/Wutwert anzeigen"] and t["Außerhalb des Kampfes abblenden"]
  and navName(pageTabs[2]) == "Leisten" and navName(pageTabs[3]) == "Symbole"
pageTabs[2]:Click(); pick("combo")
german = german and allTexts()["Combopunkt 3"] and allTexts()["Farben und Deckkraft"]
check(german, "German everywhere")
for _, f in ipairs(M.frames) do if f.lang == "enUS" and f:IsVisible() then f:Click() end end
t = allTexts()
local english = t["Colors and opacity"] and findButton("Default colors")
pageTabs[1]:Click()
t = allTexts()
check(english and t["Color"] and t["Bar background (empty part)"] and t["Show energy / rage value"] and navName(pageTabs[3]) == "Icons",
  "English uses US spelling and the new labels")
do -- every text of every page (each bar picked), and the class spells panel
  local british = {}
  local function scan()
    for _, r in ipairs(M.regions) do
      local text = r._kind == "FontString" and r._text and r._parent:IsVisible() and tostring(r._text)
      if text and text:lower():find("colour") then british[text] = true end
    end
  end
  for _, b in ipairs(pageTabs) do
    b:Click()
    scan()
    for _, key in ipairs(barKeys()) do pick(key); scan() end
  end
  pageTabs[1]:Click()
  local list = {}
  for text in pairs(british) do list[#list + 1] = "'" .. text .. "'" end
  table.sort(list)
  check(#list == 0, "English: US spelling on every page" .. (#list > 0 and (" (" .. table.concat(list, ", ") .. ")") or ""))
end
SlashCmdList.CLARACOMBOPOINTS("unlock")
check(ns.hud and allTexts()["Clara Combo Points - drag to move  (/cl lock when done)"], "mover points to /cl lock")
SlashCmdList.CLARACOMBOPOINTS("lock")
SlashCmdList.CLARACOMBOPOINTS("reset")
check(M.popup and M.popup.text:find("All your settings will be deleted", 1, true) and M.popup.buttons[1] == "Reset" and M.popup.buttons[2] == "Cancel",
  "/cl reset asks first, saying everything will be deleted")
local logged = #M.log
ns.db.fontSize = 30
M.PopupClick(1)
check(#M.log == logged and ns.db.fontSize == 17, "then resets everything, without a word in the chat")
ns:SetLanguage("frFR")
ClaraComboPointsOptions:Hide()

out("== font names fit their rows")
SlashCmdList.CLARACOMBOPOINTS("")
pageTabs[1]:Click() -- General: the font dropdown
do
  local dropdown = fontDropdown(ns.db.font)
  check(dropdown ~= nil, "font dropdown on the General page")
  M.Press(dropdown)
  local listed = M.menu ~= nil and #M.menu.items == #ns:GetFonts()
  for _, f in ipairs(ns:GetFonts()) do
    local item = M.MenuItem(f.name)
    if not (item and item.kind == "radio" and item.isSelected() == (f.name == ns.db.font)) then listed = false end
  end
  check(listed, "every font listed in the menu, the one in use ticked")
  -- each name drawn in its own font, at its list size (13, or smaller for the fonts drawn bigger)
  local probe = CreateFrame("Frame", nil, UIParent); probe:Hide()
  local drawn, pressSize = true, nil
  for _, f in ipairs(ns:GetFonts()) do
    local button = { fontString = probe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") }
    for _, fn in ipairs(M.MenuItem(f.name).initializers) do fn(button) end
    local path, size = button.fontString:GetFont()
    if path ~= f.path or size ~= (f.preview or 13) then drawn = false end
    if f.name == "Press Start 2P" then pressSize = size end
  end
  check(drawn, "each font's name drawn in its own font in the menu")
  check(pressSize == 9, "Press Start 2P drawn at 9 in the list (" .. tostring(pressSize) .. "), like the other names")
  M.Press(dropdown)
  check(not (M.menu and M.menu:IsShown()), "a second click on the dropdown closes its menu")
  -- the name of the font picked, drawn in it, fits in the dropdown
  local worst, worstName = 0, nil
  for _, f in ipairs(ns:GetFonts()) do
    M.Press(dropdown)
    M.MenuPick(f.name)
    local fs = dropdown.text
    local path, size = fs:GetFont()
    local w = MEASURE(path, size, fs._text)
    M.ResetLayout()
    local avail = select(3, M.Rect(fs))
    if fs._text ~= f.name or path ~= f.path then worst, worstName = math.huge, f.name .. " not shown" end
    if w - avail > worst then worst, worstName = w - avail, f.name end
  end
  check(worst <= 0.5, "no font name wider than the dropdown" .. (worstName and (" (" .. worstName .. " +" .. string.format("%.1f", worst) .. ")") or ""))
  M.Press(dropdown); M.MenuPick("Arial Narrow")
end
ClaraComboPointsOptions:Hide()

out(string.format("\n%d failure(s)", fails))
return fails
