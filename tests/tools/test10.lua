-- 1.5: auras in combat, where to watch, names typed in any case, icon shapes, value boxes,
-- OOC reset, drag out to remove, icon menu, class spells panel, page layout
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function rect(r) M.ResetLayout(); return M.Rect(r) end
local function label(f) return (f._textFS and f._textFS._text) or (f.text and f.text._text) end
local function findButton(text)
  for _, f in ipairs(M.frames) do if (f._kind == "Button" or f._kind == "CheckButton") and f:IsVisible() and label(f) == text then return f end end
end
local function lit(f) return f:IsShown() and not f.icon._desat and f._alpha == 1 end
local function findText(pattern)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and type(r._text) == "string" and r._text:find(pattern) and r:IsVisible() then return r end
  end
end

local ns = {}
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3; S.energy = 100
M.LoadAddon(ADDON_DIR, ns)
-- a small class spell list (the real one is in SpellCatalog.lua; this client knows few spells)
ns.SPELL_CATALOG = {
  { class = "PRIEST", spells = { { "BUFF", 139, 6074, 6075, alt = { 425268, 425269, 425270 } }, { "BUFF", 1243, 1244, 99998 }, { "SELFDEBUFF", 6788 }, { "BUFF", 99999 } } },
  { class = "MAGE", spells = { { "BUFF", 99997 } } },
  { class = "DRUID", spells = { { "BUFF", 774, 1058 }, { "DEBUFF", 8921, 8924 } } },
  { class = "WARRIOR", spells = { { "DEBUFF", 7386, 11597 }, { "BUFF", 6673 } } },
}
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100

local function slotsOf(side, k)
  local list = {}
  for _, f in ipairs(M.frames) do
    if f.cd and f.spell ~= nil and f:GetParent() and f:GetParent().spells == ns.db.rows[side][k] then list[#list + 1] = f end
  end
  return list
end

local function auraButtons(slot)
  local t = {}
  for _, f in ipairs(M.frames) do
    if f._auraButton and f._points and f._points[1] and f._points[1][2] == slot then t[#t + 1] = f end
  end
  return t
end
local function auraShown(slot) for _, b in ipairs(auraButtons(slot)) do if b:IsVisible() then return b end end end
local function slotRecord(button)
  for _, c in ipairs(M.containers) do for _, rec in pairs(c._slots) do if rec.button == button then return rec, c end end end
end
local function ids(button)
  local list = {}
  for id in pairs(slotRecord(button).ids or {}) do list[#list + 1] = id end
  table.sort(list)
  return table.concat(list, ",")
end

out("== in combat: the game's own aura buttons show the auras")
ns.db.rows.above[1] = { 774, { spell = 8921, on = "enemy" } }
ns:LayoutIcons(); M.Frame(0.016)
local rejuv, moon = slotsOf("above", 1)[1], slotsOf("above", 1)[2]
local pc, tc = ns.auraContainers.player, ns.auraContainers.target
check(pc and tc and pc._unit == "player" and tc._unit == "target" and pc._editPreview == false, "one game aura container for you, one for your target")
local rb, mb = auraButtons(rejuv), auraButtons(moon)
local filters = {}
for _, b in ipairs(rb) do local rec, c = slotRecord(b); filters[#filters + 1] = c._unit .. " " .. rec.filter end
table.sort(filters)
check(#rb == 2 and table.concat(filters, ", ") == "player HELPFUL, target HARMFUL", "auto: your buffs and your enemy target's debuffs (" .. table.concat(filters, ", ") .. ")")
check(ids(rb[1]) == "774,1058" and #mb == 1 and ids(mb[1]) == "8921,8924" and slotRecord(mb[1]).filter == "HARMFUL",
  "every rank's ID given to the game (" .. ids(rb[1]) .. " / " .. ids(mb[1]) .. "), enemy target: debuffs only")
local b1 = rb[1]
check(b1._level > rejuv._level and b1._level > rejuv.cd._level and b1._level < rejuv.over._level,
  "the game's button sits over the icon and its swipe, under the button frame")
check(b1._icon and b1._icon._masks and b1._icon._masks[1]._atlas == "UI-HUD-CoolDownManager-Mask" and b1._cd and b1._cd._abbrev == 120 and b1._count,
  "dressed like the icon: masked art, swipe with countdown, stacks")
S.auras = { player = { { name = "Rejuvenation", icon = 136081, duration = 12, expirationTime = 110, spellId = 1058 } } }
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(lit(rejuv) and auraShown(rejuv), "out of combat: Rejuvenation on you, lit (read by the addon and shown by the game)")
M.secureCallsWhileSecret = nil
M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true; S.secretAuras = true -- combat: auras hidden from addons
S.target = { hostile = true, guid = "Creature-7" }
local updates = tc._updates or 0
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
local shown = auraShown(rejuv)
check(not lit(rejuv) and shown and shown._cd._cd[2] == 12 and shown._icon._file == 136081, "combat, enemy targeted: the game's button shows Rejuvenation, with its time")
check((tc._updates or 0) > updates, "target change: the game's target container is told to look again")
S.target = { hostile = false, guid = "Player-1" }
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
check(auraShown(rejuv), "target yourself again: still shown")
S.auras.player = {}
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(not auraShown(rejuv) and not lit(rejuv), "the buff ends: grayed out")
M.now = 120
S.target = { hostile = true, guid = "Creature-8" }
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
S.auras.player = { { name = "Rejuvenation", icon = 136081, duration = 12, expirationTime = 132, spellId = 774 },
  { name = "Clearcasting", icon = 136170, duration = 15, expirationTime = 140, spellId = 16870 } }
S.auras.target = { { name = "Moonfire", icon = 136096, duration = 9, expirationTime = 134, harmful = true, spellId = 8924 } }
M.Fire("UNIT_AURA", "player"); M.Fire("UNIT_AURA", "target"); M.Frame(0.016)
check(auraShown(rejuv) and auraShown(moon) and auraShown(moon)._cd._cd[2] == 9 and auraShown(moon)._icon._file == 136096,
  "cast in combat: Rejuvenation (rank 1) and Moonfire on the enemy shown")
S.target = { hostile = false }
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
check(not auraShown(moon), "Moonfire on a friendly target: not shown by an enemy-target icon")
M.restrictedWhileSecret = nil
ns:SetIconEntry("above", 1, 2, nil, "target")
M.Frame(0.016)
local moonFilters = {}
for _, b in ipairs(auraButtons(moon)) do local rec = slotRecord(b); if rec.enabled then moonFilters[#moonFilters + 1] = rec.filter end end
table.sort(moonFilters)
check(table.concat(moonFilters, ",") == "HARMFUL,HELPFUL", "changed in combat: the game's containers follow at once (target: buffs and debuffs)")
ns.db.icons.reverse = true; ns:SyncAuraButtons(); M.Frame(0.016)
check(not M.restrictedWhileSecret and auraButtons(rejuv)[1]._cd._reverse ~= true, "the game's buttons are not touched while auras are secret: their look waits")
S.secretAuras = false; S.inCombat = false; M.Fire("PLAYER_REGEN_ENABLED"); M.Frame(0.016)
check(auraButtons(rejuv)[1]._cd._reverse == true, "combat over: their look follows")
ns.db.icons.reverse = false; ns:SyncAuraButtons()
ns:SetIconEntry("above", 1, 2, nil, "enemy")

out("== IDs learned when an aura is seen")
S.auras = { player = { { name = "Rejuvenation", icon = 136081, duration = 12, expirationTime = 200, spellId = 99001 } } }
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(ClaraComboPointsDB.auraIDs.rejuvenation and ClaraComboPointsDB.auraIDs.rejuvenation[99001] and ids(auraButtons(rejuv)[1]) == "774,1058,99001",
  "Rejuvenation seen under another ID: remembered and given to the game")
M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true; S.secretAuras = true; M.Frame(0.016)
check(auraShown(rejuv), "in combat, shown under that ID")
S.secretAuras = false; S.inCombat = false; M.Fire("PLAYER_REGEN_ENABLED")
S.auras = nil; S.target = nil
M.Fire("PLAYER_TARGET_CHANGED"); M.Fire("UNIT_AURA", "player"); M.Frame(0.016)

out("== /cl debug")
M.log = {}
SlashCmdList.CLARACOMBOPOINTS("debug")
local report = table.concat(M.log, "\n")
check(report:find("auras secret: false, aura containers: player true, target true") and report:find("Top 1 1: Rejuvenation %(774%) on auto, IDs 774,1058,99001"),
  "what each icon watches, for a report")

out("== where to watch")
S.target = { hostile = false }
S.auras = { target = { { name = "Moonfire", icon = 136096, duration = 9, expirationTime = 150, harmful = true } } }
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
check(not lit(moon), "watched on an enemy target: not lit on a friendly target")
S.target = { hostile = true }
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
check(lit(moon), "enemy target: lit")
S.auras = { player = { { name = "Moonfire", icon = 136096, duration = 9, expirationTime = 150, harmful = true } } }
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(not lit(moon), "the same debuff on you does not count for an enemy-target icon")
S.auras = nil; S.target = nil
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)

out("== names typed in any case")
ns.db.rows.above[1] = {}
ns:LayoutIcons()
local ok, msg = ns:AddIcon("above", 1, "renew")
check(ok and ns.db.rows.above[1][1] == 6075, "'renew' found in the class spell lists: stored as its ID (" .. tostring(msg) .. ")")
ok = ns:AddIcon("above", 1, "power word: shield")
check(ok and ns.db.rows.above[1][2] == "power word: shield", "unknown name: tracked by name as typed")
S.auras = { player = { { name = "Power Word: Shield", icon = 135940, duration = 30, expirationTime = 200, spellId = 17 } } }
ns:LayoutIcons(); M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
local shield = slotsOf("above", 1)[2]
check(lit(shield) and shield.icon._file == 135940, "typed in lower case, still recognised on you, real icon learned")
S.auras.player[2] = { name = "Clearcasting", icon = 136170, duration = 15, expirationTime = 200, spellId = 16870 }
ok, msg = ns:AddIcon("above", 1, "clearcasting")
check(ok and ns.db.rows.above[1][3] == 16870, "a name found among the auras on you: stored as its ID")
ns.db.rows.above[1] = { "renew" }
ok, msg = ns:AddIcon("above", 1, 139)
check(ok and #ns.db.rows.above[1] == 1 and ns.db.rows.above[1][1] == 139, "adding the ID of a name typed before replaces it (" .. tostring(msg) .. ")")
ok, msg = ns:AddIcon("above", 1, 6074)
check(not ok and msg == "Renew is already in this row.", "the same spell twice is still refused")
ok = ns:AddIcon("above", 1, { spell = 139, on = "friend" })
check(ok and #ns.db.rows.above[1] == 2, "the same spell watched elsewhere (friendly target) is allowed")
ok = ns:AddIcon("above", 1, { spell = 6074, exact = true })
check(ok and #ns.db.rows.above[1] == 3, "one rank apart from all ranks is allowed")
ns.db.rows.above[1] = { { spell = 6075, exact = true, on = "self" } }
ns:LayoutIcons()
local rank3 = slotsOf("above", 1)[1]
S.auras = { player = { { name = "Renew", icon = 135953, duration = 15, expirationTime = 200, spellId = 425270 } } }
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(lit(rank3), "rank 3 only: lit by rank 3 under its other ID (Forever)")
S.auras.player[1].spellId = 6074
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(not lit(rank3), "rank 3 only: rank 2 does not count")
S.auras = nil
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)

out("== options: icon shapes")
ns.db.rows.above[1] = { 774, 8921, 1243 }
ns:LayoutIcons()
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
for _, f in ipairs(M.frames) do if f.page == 3 then f:Click() end end
local cell = findButton("Rectangular")
check(findButton("Bar width") and cell and findButton("Square"), "three shapes: bar width, rectangular, square")
check(findButton("Square")._locked and not cell._locked, "square selected by default")
cell:Click()
check(ns.db.icons.shape == "CELL" and cell._locked, "combo point picked")
check(findText("^a combo point's size %(56 × 25%)") ~= nil, "size: the combo point's, shown instead of the slider")
local sizeSlider
for _, f in ipairs(M.frames) do if f._kind == "Slider" and f._min == 12 and f._max == 64 then sizeSlider = f end end
check(not sizeSlider:IsVisible() and not sizeSlider.box.holder:IsVisible(), "size slider hidden for combo point cells")
findButton("Square"):Click()
check(ns.db.icons.shape == "SQUARE" and sizeSlider:IsVisible(), "square: size slider back")
findButton("Bar width"):Click()

out("== value boxes beside the sliders")
for _, f in ipairs(M.frames) do if f.page == 1 then f:Click() end end
local sliders = {}
for _, f in ipairs(M.frames) do if f._kind == "Slider" and f.box and f:IsVisible() then sliders[#sliders + 1] = f end end
local withBox = 0
for _, s in ipairs(sliders) do if s.box.holder:IsVisible() then withBox = withBox + 1 end end
check(#sliders >= 4 and withBox == #sliders, "every slider has its value box (" .. #sliders .. ")")
local oocPower
for _, s in ipairs(sliders) do if s.box:GetText() == "20" and s._w == 100 then oocPower = oocPower or s end end
local box = oocPower.box
box:SetFocus(); box:SetText("35"); box._scripts.OnEnterPressed(box)
check(near(ns.db.oocPower, .35) and box:GetText() == "35" and oocPower:GetValue() == 35, "35 typed + Enter: applied, slider follows")
box:SetFocus(); box:SetText("250"); box._scripts.OnEnterPressed(box)
check(near(ns.db.oocPower, 1) and box:GetText() == "100", "250: kept within 0-100")
box:SetFocus(); box:SetText("7"); box:ClearFocus()
check(box:GetText() == "100" and near(ns.db.oocPower, 1), "left without Enter: the box shows the value again")
oocPower:SetValue(60)
check(box:GetText() == "60", "dragging the slider updates the box")

out("== out of combat: back to defaults")
ns.db.fadeOOC = false; ns.db.oocTop = .7
panel:Refresh()
local reset = findButton("Reset to default")
check(reset ~= nil, "a reset button in the out of combat group")
reset:Click()
check(ns.db.fadeOOC == false and near(ns.db.oocPower, .2) and near(ns.db.oocTop, .2) and oocPower.box:GetText() == "20", "fade back to its default (off), 20 % and 20 %")
for _, class in ipairs({ "ROGUE", "WARRIOR" }) do
  for _, f in ipairs(M.frames) do if f.class == class then f:Click() end end
  check(findButton("Reset to default") ~= nil, "reset button on the " .. class:lower() .. " tab too")
end
for _, f in ipairs(M.frames) do if f.class == "DRUID" then f:Click() end end

out("== icons page: no overlap, the bear option above the tracked rows")
for _, f in ipairs(M.frames) do if f.page == 3 then f:Click() end end
local bear = findButton("Bear Form: icons stay above the combo points")
local header = findText("^Tracked buffs, debuffs and spells$")
local _, bb = rect(bear)
local _, hb, _, hh = rect(header)
check(bear and bb > hb + hh + 10, "bear option above the 'tracked' header")
local boxes = {}
local function under(f, root) while f do if f == root then return true end f = f._parent end return false end
for _, f in ipairs(M.frames) do if M.IsGroupBox(f) and f:IsVisible() and under(f, panel.sheet) then boxes[#boxes + 1] = f end end
local overlap = false
for i = 1, #boxes do
  for j = i + 1, #boxes do
    local al, ab, aw, ah = rect(boxes[i]); local bl, bb2, bw, bh = rect(boxes[j])
    if al < bl + bw and bl < al + aw and ab < bb2 + bh and bb2 < ab + ah then overlap = true end
  end
end
local titles = {}
for _, b2 in ipairs(boxes) do titles[#titles + 1] = tostring(b2.title and b2.title._text) end
table.sort(titles)
check(table.concat(titles, ",") == "Add a spell,Icon look,On the bar,Tracked buffs, debuffs and spells" and not overlap,
  "the four groups (icon look, add a spell, on the bar, tracked rows) do not overlap (" .. table.concat(titles, ",") .. ")")
local inside = true
local pl, pb, pw, ph = rect(panel)
local iconsPage = boxes[1] and boxes[1].title._parent -- the page the group titles are written on
local function onPage(f) while f do if f == iconsPage then return true end f = f._parent end return false end
for _, lang in ipairs({ "enUS", "frFR", "deDE" }) do
  ns:SetLanguage(lang)
  for _, f in ipairs(M.frames) do
    if (f._kind == "CheckButton" or (f._kind == "Button" and f._template == "UIPanelButtonTemplate")) and f:IsVisible() then
      local l, b, w, h = rect(f)
      local right = l + w + (f._kind == "CheckButton" and f.Text:GetStringWidth() + 1 or 0)
      local inAny = false
      for _, box2 in ipairs(boxes) do
        local xl, xb, xw, xh = rect(box2)
        local overBox = l < xl + xw and right > xl and b < xb + xh and b + h > xb
        local within = l >= xl and right <= xl + xw and b >= xb and b + h <= xb + xh
        if within then inAny = true end
        if overBox and not within then inside = false; out("    " .. lang .. " sticks out: " .. tostring(label(f) or f.Text._text)) end
      end
      -- a widget of the icons page must be in one of its groups, not loose beside them
      if not inAny and onPage(f) then inside = false; out("    " .. lang .. " outside every group: " .. tostring(label(f) or f.Text._text)) end
    end
  end
end
ns:SetLanguage("enUS")
check(inside, "every checkbox and button stays inside its group, in the three languages")
local tip = findText("^Icons: drag to move")
local _, tb = rect(tip)
local _, lastB = rect(boxes[1])
for _, b2 in ipairs(boxes) do local _, y = rect(b2); if y < lastB then lastB = y end end
check(tb > lastB and lastB > pb + 30, "the help under the rows stays in its group, above the footer")

out("== drag an icon out of the window: removed")
local lines = {}
for _, f in ipairs(M.frames) do if f._kind == "Button" and f._w == 680 and f:IsVisible() then lines[#lines + 1] = f end end
local top1 = lines[3]
local function icons(line)
  local list = {}
  for _, f in ipairs(M.frames) do if f._parent == line and f._kind == "Button" and f:IsShown() then list[#list + 1] = f end end
  return list
end
local ic = icons(top1)
check(#ic == 3, "Top 1 shows its 3 icons")
M.mouseDown = true
ic[3]._scripts.OnDragStart(ic[3])
M.cursorX, M.cursorY = 2, 2; M.Frame(0.016) -- bottom left of the screen, away from the window
local ghost
for _, f in ipairs(M.frames) do if f.cross then ghost = f end end
check(ghost:IsShown() and ghost.cross:IsShown(), "outside the window: the dragged icon shows it will be removed")
M.mouseDown = false; ic[3]._scripts.OnDragStop(ic[3])
check(#ns.db.rows.above[1] == 2 and findText("^Power Word: Fortitude removed %(Top 1%)%.$") ~= nil, "let go outside: removed, with a message")
M.mouseDown = true
ic[2]._scripts.OnDragStart(ic[2])
M.CursorOn(panel, 0); M.Frame(0.016)
check(not ghost.cross:IsShown(), "back over the window: not removed")
M.mouseDown = false; ic[2]._scripts.OnDragStop(ic[2])
check(#ns.db.rows.above[1] == 2, "let go inside the window, off the rows: it stays")

out("== click on an icon: where to watch, rank, remove")
ic = icons(top1)
ic[1]:Click("LeftButton")
check(M.menu and M.menu.items[1].kind == "title" and M.menu.items[1].text == "Rejuvenation", "a menu opens, titled with the spell")
local radios = {}
for _, item in ipairs(M.menu.items) do if item.kind == "radio" then radios[#radios + 1] = item.text end end
check(table.concat(radios, ",") == "Auto (you, then your target),Self,Target,Enemy target,Friendly target,All ranks,Rank 1,Rank 2",
  "watch on, then ranks: " .. table.concat(radios, ","))
check(M.MenuItem("Auto (you, then your target)").isSelected() and M.MenuItem("All ranks").isSelected(), "current choices ticked")
M.MenuPick("Self")
local e = ns.db.rows.above[1][1]
check(type(e) == "table" and e.spell == 774 and e.on == "self" and not e.exact, "Self picked: saved")
ic = icons(top1); ic[1]:Click("LeftButton")
M.MenuPick("Rank 2")
e = ns.db.rows.above[1][1]
check(e.spell == 1058 and e.exact == true and e.on == "self", "Rank 2 picked: that rank only, still on you")
ic = icons(top1); ic[1]._scripts.OnEnter(ic[1])
local tipText = table.concat(GameTooltip._lines, "|")
check(tipText:find("Rank 2") and tipText:find("Watched on: Self"), "tooltip: rank and where it is watched (" .. tipText .. ")")
ic[1]:Click("LeftButton")
M.MenuPick("Auto (you, then your target)")
ic = icons(top1); ic[1]:Click("LeftButton")
M.MenuPick("All ranks")
check(ns.db.rows.above[1][1] == 1058, "back to auto and all ranks: a plain spell again")
ic = icons(top1); ic[1]:Click("LeftButton")
M.MenuPick("Remove")
check(#ns.db.rows.above[1] == 1 and ns.db.rows.above[1][1] == 8921, "Remove")

out("== class spells panel")
local side = ClaraComboPointsSpells
check(side and side:IsVisible(), "shown beside the window on the icons page")
local sl, sb, sw, sh = rect(side)
check(near(sl, pl + pw) and near(sb + sh, pb + ph), "attached to the window's right side")
check(side.TitleContainer.TitleText._text == "Class buffs and debuffs" and findText("^Every buff and debuff of each class") ~= nil, "title and how to use it")
local heads = {}
for _, g in ipairs(side.groups) do heads[#heads + 1] = g.class end
check(table.concat(heads, ",") == "PRIEST,DRUID,WARRIOR", "classes in order, those without spells this client knows left out (" .. table.concat(heads, ",") .. ")")
local function rowsOf(g) local n = 0; for _, r in ipairs(g.rows or {}) do if r:IsShown() then n = n + 1 end end return n end
check(rowsOf(side.groups[2]) == 2 and rowsOf(side.groups[1]) == 0, "the tab's class unfolded (druid), the others folded")
side.groups[1].head:Click()
check(rowsOf(side.groups[1]) == 3, "click a class: unfolded (3 spells this client knows)")
local priestRows = side.groups[1].rows
local function rowNamed(rows, name)
  for _, r in ipairs(rows) do for _, region in ipairs(M.regions) do if region._parent == r and region._text == name then return r end end end
end
local renew, fort, weak = rowNamed(priestRows, "Renew"), rowNamed(priestRows, "Power Word: Fortitude"), rowNamed(priestRows, "Weakened Soul")
check(renew and fort and weak, "spells sorted, named in the client's language")
local _, rb1 = rect(fort); local _, rb2 = rect(renew); local _, rb3 = rect(weak)
check(rb1 > rb2 and rb2 > rb3, "alphabetical order")
check(renew.rank and renew.rank.text._text == "All ranks" and renew.on.text._text == "Self", "Renew: all ranks, watched on yourself by default")
check(weak.rank == nil and weak.on.text._text == "Self", "one rank only: no rank choice")
renew.rank:Click()
local choices = {}
for _, item in ipairs(M.menu.items) do choices[#choices + 1] = item.text end
check(table.concat(choices, ",") == "All ranks,Rank 1,Rank 2,Rank 3", "rank menu: " .. table.concat(choices, ","))
M.MenuPick("Rank 2")
renew.on:Click()
choices = {}
for _, item in ipairs(M.menu.items) do choices[#choices + 1] = item.text end
check(table.concat(choices, ",") == "Self,Target,Enemy target,Friendly target", "watch menu: " .. table.concat(choices, ","))
M.MenuPick("Friendly target")
check(renew.rank.text._text == "Rank 2" and renew.on.text._text == "Friendly target", "choices shown")
lines[4]:Click() -- Bottom 1 selected
renew:Click()
e = ns.db.rows.below[1][1]
check(type(e) == "table" and e.spell == 6074 and e.exact and e.on == "friend" and findText("^Renew added %(Bottom 1%)%.$"), "click: added to the selected row, rank and target as chosen")
M.mouseDown = true
fort._scripts.OnDragStart(fort)
local top1Icons = icons(top1)
M.CursorOn(top1Icons[1]); M.Frame(0.016)
check(icons(top1)[1].spell == 1244 and icons(top1)[1].landing:IsShown(), "dragged over Top 1: room made before its first icon")
M.mouseDown = false; fort._scripts.OnDragStop(fort)
e = ns.db.rows.above[1][1]
check(type(e) == "table" and e.spell == 1244 and e.on == "self" and ns.db.rows.above[1][2] == 8921, "dropped: added there (Power Word: Fortitude, on you)")
M.mouseDown = true
fort._scripts.OnDragStart(fort)
M.cursorX, M.cursorY = 2, 2; M.Frame(0.016)
M.mouseDown = false; fort._scripts.OnDragStop(fort)
check(#ns.db.rows.above[1] == 2, "a spell of the list let go elsewhere: nothing happens")
M.mouseDown = true
local ab = icons(top1)
ab[2]._scripts.OnDragStart(ab[2])
M.CursorOn(renew); M.Frame(0.016)
M.mouseDown = false; ab[2]._scripts.OnDragStop(ab[2])
check(#ns.db.rows.above[1] == 2, "an icon let go over the spells panel is kept")

out("== the panel comes and goes")
local close
for _, f in ipairs(M.frames) do if f._parent == side and f._template == "UIPanelCloseButton" then close = f end end
close:Click()
check(not side:IsShown() and panel:IsShown(), "its close button hides it, the window stays")
local open = findButton("Class spells")
open:Click()
check(side:IsShown() and open._locked, "the 'Class spells' button shows it again")
for _, f in ipairs(M.frames) do if f.page == 1 then f:Click() end end
check(not side:IsShown(), "other pages: hidden")
for _, f in ipairs(M.frames) do if f.page == 3 then f:Click() end end
check(side:IsShown(), "icons page: back")
check(not (side.groups[1].rows[1] and side.groups[1].rows[1]:IsShown()), "back on the tab's class: the priests folded again")
side.groups[1].head:Click()
ns:SetLanguage("frFR")
check(side.TitleContainer.TitleText._text == "Buffs et debuffs des classes" and renew.on.text._text == "Cible amie"
  and findText("^Prêtre$") ~= nil, "language switch: panel relabelled")
ns:SetLanguage("enUS")
panel:Hide()
check(not side:IsVisible(), "closed with the window")

out("== the panel stays on screen")
local sw0 = M.ScreenSize()
-- the window (888 wide) kept 40 from the screen's right edge: it fits, the panel beside it does not
-- (the window opens where it was kept: ns.sv.window, at scale 1 here)
ns.sv.window.left, ns.sv.window.top = sw0 - 928, 900
panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", sw0 - 928, 900)
side:Hide()
SlashCmdList.CLARACOMBOPOINTS("")
local ssl, _, ssw = rect(side)
local wl = rect(panel)
check(side:IsShown() and wl < sw0 - 928 - 1 and ssl + ssw <= sw0 + 0.01,
  "window moved left so the panel fits (" .. math.floor(wl) .. " < " .. math.floor(sw0 - 928) .. ", " .. math.floor(ssl + ssw) .. " <= " .. math.floor(sw0) .. ")")
panel:Hide()

out(string.format("\n%d failure(s)", fails))
return fails
