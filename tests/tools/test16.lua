-- square icons by default, cast-by-me tracking, spell search in any language, mana and health
-- bars (sizes, order, colours), icons edited on the HUD
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
local function findText(pattern)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text and r:IsShown() and r._parent:IsVisible() and tostring(r._text):find(pattern, 1, true) then return r end
  end
end

local ns = {}
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 0 -- caster form
S.mana, S.manaMax, S.health, S.healthMax = 1200, 3000, 900, 1500
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local L = ns.L
M.now = 100

out("== icons: square by default")
check(ns.db.icons.shape == "SQUARE" and ns.defaults.icons.shape == "SQUARE", "square by default")
ns:SetLanguage("frFR")
check(L.SHAPE_SQUARE == "Carré" and L.SHAPE_CELL == "Rectangulaire", "shapes: Carré, Rectangulaire")

out("== search keys")
check(ns:SearchKey("Mot de pouvoir : Robustesse") == "mot de pouvoir robustesse", "punctuation and spacing")
check(ns:SearchKey("ÉCLAT  lunaire") == ns:SearchKey("eclat lunaire") and ns:SearchKey("Verjüngung") == "verjungung"
  and ns:SearchKey("Elune's Grace") == "elunes grace" and ns:SearchKey("Œil") == "oeil", "accents, case, apostrophes, œ")

out("== class spells in the addon's language")
local renew = ns:CatalogRecord(139)
check(renew and renew.names and renew.names[2] == "Rénovation" and renew.names[3] == "Erneuerung", "Renew knows its French and German names")
check(ns:CatalogName(renew) == "Rénovation", "English client, French addon: shown in French")
ns:SetLanguage("deDE")
check(ns:CatalogName(renew) == "Erneuerung", "German addon: in German")
ns:SetLanguage("enUS")
check(ns:CatalogName(renew) == "Renew", "English addon on an English client: the game's name")
ns:SetLanguage("frFR")
check(ns:CatalogMatches(renew, ns:SearchKey("renov")) and ns:CatalogMatches(renew, ns:SearchKey("ERNEUER"))
  and ns:CatalogMatches(renew, ns:SearchKey("renew")) and ns:CatalogMatches(renew, "6074") and not ns:CatalogMatches(renew, "774"),
  "found by part of any language's name, accents and case aside, or any rank's ID")

out("== add a spell by its name in any language")
ns.db.rows.above[1] = {}
local ok, msg = ns:AddIcon("above", 1, "Récupération")
check(ok and ns:EntrySpell(ns.db.rows.above[1][1]) == 1058, "French name on an English client: added (highest rank known)")
ok, msg = ns:AddIcon("above", 1, "ERNEUERUNG")
check(ok and ns:EntrySpell(ns.db.rows.above[1][2]) ~= nil and ns:SpellName(ns:EntrySpell(ns.db.rows.above[1][2])) == "Renew",
  "whole German name, in capitals: Renew")
ok, msg = ns:AddIcon("above", 1, "Slow")
check(ok and ns.db.rows.above[1][3] == "Slow", "part of a class spell's name (Slow Fall): followed by the name typed (" .. tostring(ns.db.rows.above[1][3]) .. ")")
ok, msg = ns:AddIcon("above", 1, "Stun")
check(ok and ns.db.rows.above[1][4] == "Stun", "part of German names (-rüstung): followed by the name typed, no refusal (" .. tostring(msg) .. ")")
ok, msg = ns:AddIcon("above", 1, "Well Fed")
check(ok and ns.db.rows.above[1][5] == "Well Fed", "a name no class spell has: followed by its name, as before")
ns.db.rows.above[1] = {}

out("== class spells panel: search, By me")
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
for _, f in ipairs(M.frames) do if f.page == 3 then f:Click() end end
local side = ClaraComboPointsSpells
local search = side.search
check(search and search:IsVisible() and findText("Rechercher"), "a search box at the top, with a hint")
local function shownRows()
  local list = {}
  for _, g in ipairs(side.groups) do
    for _, r in ipairs(g.rows or {}) do
      if r:IsShown() then
        for _, region in ipairs(M.regions) do if region._parent == r and region._maxLines == 2 then list[#list + 1] = region._text end end
      end
    end
  end
  return list
end
M.Type(search, "rénov")
local found = shownRows()
check(#found == 1 and found[1] == "Rénovation", "\"rénov\": Renew alone, in French (" .. table.concat(found, ", ") .. ")")
M.Type(search, "VERJUNG")
found = shownRows()
check(#found == 1 and found[1] == "Récupération", "German name, no umlaut, capitals: Rejuvenation (" .. table.concat(found, ", ") .. ")")
M.Type(search, "8924")
found = shownRows()
check(#found == 1 and found[1] == "Éclat lunaire", "a rank's ID: Moonfire (" .. table.concat(found, ", ") .. ")")
M.Type(search, "zzz")
check(#shownRows() == 0 and findText("Aucun sort trouvé"), "nothing found: said so")
M.Type(search, "")
check(not findText("Aucun sort trouvé"), "cleared: the whole list again")
-- By me
M.Type(search, "récup")
local row
for _, g in ipairs(side.groups) do for _, r in ipairs(g.rows or {}) do if r:IsShown() then row = r end end end
check(row and row.mine and row.mine:IsVisible() and findText("Par moi"), "a By me box on each spell")
row.mine:Click()
ns.db.rows.above[1] = {}
for _, line in ipairs(M.frames) do end
row:Click()
local entry = ns.db.rows.above[1][1]
check(type(entry) == "table" and entry.mine == true and entry.spell == 1058, "added with By me: only the aura you cast")
M.Type(search, "")

out("== cast by me: only your own aura")
panel:Hide() -- (open, the options light every icon)
S.powerType = 3; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016)
ns:LayoutIcons(); M.Frame(0.016)
local slot
for _, f in ipairs(M.frames) do if f.cd and f.spell == 1058 then slot = f end end
S.auras = { player = { { name = "Rejuvenation", icon = 136081, duration = 12, expirationTime = M.now + 12, spellId = 774, source = "other" } } }
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(slot and slot.icon._desat == true, "another druid's Rejuvenation: not yours, grayed out")
S.auras.player[2] = { name = "Rejuvenation", icon = 136081, duration = 12, expirationTime = M.now + 12, spellId = 774, source = "player" }
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(slot.icon._desat == false, "yours: lit")
local filters = {}
for _, c in ipairs(M.containers) do for _, rec in pairs(c._slots) do if rec.enabled and rec.ids and rec.ids[774] then filters[#filters + 1] = rec.filter end end end
check(#filters >= 1 and filters[1]:find("PLAYER", 1, true), "the game's aura button too: " .. table.concat(filters, ", "))
-- icon menu
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f.page == 3 then f:Click() end end
local lines = {}
for _, f in ipairs(M.frames) do if f.tex and f.entry ~= nil and f:IsVisible() and f.index == 1 then lines[#lines + 1] = f end end
local icon = lines[1]
icon:Click()
local item = M.MenuItem("Lancé par moi uniquement")
check(item and item.kind == "checkbox" and item.isSelected(), "the icon's menu: Cast by me only, ticked")
M.MenuPick("Lancé par moi uniquement")
entry = ns.db.rows.above[1][1]
check(not (type(entry) == "table" and entry.mine), "unticked from the menu: anyone's")
S.auras = {}
ns.db.rows.above[1] = {}
ns:LayoutIcons()

out("== druid: mana bar in every form")
local mana, health, power, combo = ns.manaBar, ns.healthBar, ns.powerBar, ns.comboRow
panel:Hide()
S.powerType = 0; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016)
check(ns.hud:IsShown() and mana:IsShown() and not power:IsShown() and not combo:IsShown(), "caster form: the mana bar alone")
check(M.reveal(mana._value) == 1200 and mana._max == 3000 and mana.text._text == 1200, "mana 1200 / 3000")
S.mana = 1100; M.Frame(0.016)
check(M.reveal(mana._value) == 1100, "mana read every frame")
S.powerType = 3; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016)
check(mana:IsShown() and power:IsShown() and combo:IsShown(), "cat form: combo points, energy and mana")
local function top(f) M.ResetLayout(); local _, b, _, h = M.Rect(f); return (b + h) * f:GetEffectiveScale() end
local function bottom(f) M.ResetLayout(); local _, b = M.Rect(f); return b * f:GetEffectiveScale() end
check(top(combo) > top(power) and top(power) > top(mana), "top to bottom: combo points, energy, mana")
check(not health:IsShown() and ns.db.bars.health.show == false, "health bar off by default")

out("== health bar")
ns.db.bars.health.show = true; ns:ApplyLayout()
check(health:IsShown() and M.reveal(health._value) == 900 and health._max == 1500 and bottom(health) < bottom(mana), "turned on: under the mana bar, 900 / 1500")
local c = health._barcolor
check(c[1] == 0 and c[2] == 1 and c[3] == 0, "the game's health green")
ns.db.healthClassColor = true; ns:ApplyColors()
c = health._barcolor
check(near(c[1], 1) and near(c[2], .49) and near(c[3], .04), "class colour: druid orange")
ns.db.healthClassColor = false; ns.db.colors.health = { r = .2, g = .3, b = .4, a = 1 }; ns:ApplyColors()
check(near(health._barcolor[1], .2) and near(health._barcolor[3], .4), "any colour from the picker")
c = mana._barcolor
check(c[1] == 0 and c[2] == 0 and c[3] == 1, "mana: the game's blue")
S.health = 800; M.Frame(0.016)
check(M.reveal(health._value) == 800, "health read every frame")

out("== bar sizes and order")
ns.db.bars.power.width, ns.db.bars.power.height, ns.db.bars.power.scale = 200, 30, 1.5
ns:ApplyLayout()
check(power._w == 200 and power._h == 30 and power._scale == 1.5, "energy bar: 200 x 30 at 150 %")
ns.db.bars.order = { "health", "mana", "combo", "power" }; ns:ApplyLayout()
check(top(health) > top(mana) and top(mana) > top(combo) and top(combo) > top(power), "order: health, mana, combo points, energy")
ns.db.bars.power.width, ns.db.bars.power.height, ns.db.bars.power.scale = 292, 24, 1
ns.db.bars.order = { "combo", "power", "mana", "health" }; ns:ApplyLayout()

out("== bars page: drag a bar")
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f.page == 2 then f:Click() end end
check(findText("Barres, de haut en bas") and findButton("Taille par défaut"), "Bars page: the bars and their size")
local barRows = {}
for _, f in ipairs(M.frames) do if f.key and f.show and f:IsVisible() then barRows[#barRows + 1] = f end end
table.sort(barRows, function(a, b) return top(a) > top(b) end)
local names = {}
for i, r in ipairs(barRows) do names[i] = r.key end
check(table.concat(names, ",") == "combo,power,mana,health", "listed top to bottom: " .. table.concat(names, ","))
-- drag health to the top
M.CursorOn(barRows[4])
M.mouseDown = true
barRows[4]._scripts.OnDragStart(barRows[4])
M.CursorOn(barRows[1])
M.Frame(0.016)
M.mouseDown = false
M.Frame(0.016)
check(table.concat(ns.db.bars.order, ",") == "health,combo,power,mana", "health dragged to the top: " .. table.concat(ns.db.bars.order, ","))
check(top(health) > top(combo), "the HUD follows")
-- size of the bar picked (the sliders of the page itself; each colour row has its opacity slider)
for _, r in ipairs(barRows) do if r.key == "mana" then r:Click() end end
local barsPage = barRows[1]:GetParent():GetParent()
local manaColor = findText("Barre de mana")
check(manaColor and findText("Couleurs et opacité") and not findText("Barre de vie") and not findText("Point de combo 1")
  and manaColor._parent.on and not manaColor._parent.on:IsShown(),
  "mana picked: its own colour row on the right (no box: the list's box switches it), not the other bars'")
local sliders = {}
for _, f in ipairs(M.frames) do if f._kind == "Slider" and f:IsVisible() and (f:GetParent() == barsPage or f:GetParent() == barsPage.colR) then sliders[#sliders + 1] = f end end
table.sort(sliders, function(a, b) return top(a) > top(b) end)
check(#sliders == 3 and sliders[1]._min == ns.MIN_BAR_W and sliders[1]._max == ns.MAX_BAR_W
  and sliders[2]._min == ns.MIN_BAR_H and sliders[2]._max == ns.MAX_BAR_H
  and sliders[3]._min == ns.MIN_BAR_SCALE and sliders[3]._max == ns.MAX_BAR_SCALE, "width, height, scale (" .. #sliders .. " sliders)")
sliders[2]:SetValue(20)
check(ns.db.bars.mana.height == 20 and mana._h == 20, "mana height 20")
sliders[3]:SetValue(200)
check(ns.db.bars.mana.scale == 2 and mana._scale == 2, "mana scale 200 %")
findButton("Taille par défaut"):Click()
check(ns.db.bars.mana.height == 12 and ns.db.bars.mana.scale == 1, "default size")
-- turn health off from the list
for _, r in ipairs(barRows) do if r.key == "health" and r.show:IsVisible() then r.show.check:Click() end end
check(ns.db.bars.health.show == false, "health turned off from the list")
panel:Hide()

out("== rogue: no mana bar")
ns:SetActiveProfile("ROGUE")
check(not mana:IsShown(), "rogue tab: no mana bar")
ns:SetActiveProfile("DRUID")

out("== icons edited on the HUD")
ns.db.rows.above[1] = { 774 }
ns.db.rows.below[1] = {}
ns:LayoutIcons()
local rowsOf = {}
for _, f in ipairs(M.frames) do if f.hit and f.side then rowsOf[f.side .. f.k] = f end end
check(not rowsOf.below1:IsShown() and not rowsOf.above1.hit:IsShown(), "locked: empty rows hidden, no drop areas")
ns:SetIconsLocked(false)
check(rowsOf.below1:IsShown() and rowsOf.below1.hit:IsShown() and rowsOf.above3:IsShown(), "unlocked: every row shows, the empty ones too")
check(rowsOf.below1.hit.label._text == "Bas 1 : dépose un sort ici", "an empty row says where it is: " .. tostring(rowsOf.below1.hit.label._text))
local slot1 = rowsOf.above1.slots[1]
check(slot1._mouse == true, "icons take the mouse")
-- a spell from the spellbook dropped on an empty row
M.cursorSpell = 8921
rowsOf.below1.hit._scripts.OnReceiveDrag(rowsOf.below1.hit)
check(ns:EntrySpell(ns.db.rows.below[1][1]) == 8921 and M.cursorSpell == nil, "dropped from the spellbook on Bas 1: added")
-- an icon moved to another row
ns:LayoutIcons()
M.CursorOn(slot1)
M.mouseDown = true
slot1._scripts.OnDragStart(slot1)
M.CursorOn(rowsOf.below1.hit, 50)
M.Frame(0.016)
M.mouseDown = false
M.Frame(0.016)
check(#ns.db.rows.above[1] == 0 and ns:EntrySpell(ns.db.rows.below[1][2]) == 774, "dragged to the end of Bas 1: moved")
-- and off the HUD
local moved = rowsOf.below1.slots[2]
M.CursorOn(moved)
M.mouseDown = true
moved._scripts.OnDragStart(moved)
M.cursorX, M.cursorY = 5, 5
M.Frame(0.016)
M.mouseDown = false
M.Frame(0.016)
check(#ns.db.rows.below[1] == 1, "dragged off the bar: removed")
ns:SetIconsLocked(true)
check(not rowsOf.above1:IsShown() and rowsOf.below1.slots[1]._mouse == false, "locked again: empty rows gone, icons let the mouse through")
ns:SetIconsLocked(false)
SlashCmdList.CLARACOMBOPOINTS("lock")
check(ns.db.iconsLocked == true, "/cl lock locks the icons too")
-- the same from the options: Icons page, "Edit icons right on the bar"
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f.page == 3 then f:Click() end end
local onHud = findButton("Barre et icônes déverrouillées")
check(onHud and onHud:IsVisible() and not onHud:GetChecked(), "Icons page: Edit icons right on the bar, unticked while locked")
onHud:Click()
check(ns.db.iconsLocked == false and ns.sv.profiles.ROGUE.iconsLocked == false and rowsOf.below1.hit:IsShown() and ns.db.locked == false,
  "ticked: the icons unlocked (every class), the drop areas on the HUD, the bar movable too")
onHud:Click()
check(ns.db.iconsLocked == true and not rowsOf.below1.hit:IsShown() and ns.db.locked == true, "unticked: locked again, the bar too")
panel:Hide()

out("== profiles leave the locks out")
ns:SaveProfile("DRUID", "Test")
ns.db.iconsLocked = false
check(not ns:ProfileModified("DRUID"), "unlocking the icons does not change the profile")
ns.db.iconsLocked = true

out(string.format("\n%d failure(s)", fails))
return fails
