-- the window sized by its corner (left button: width and height, the pages laid out again and
-- scrolled; right button: scale; double click: back to the defaults), the spells panel too
-- (locked beside the window, on its left or right; on its own), the panel's known spells only
-- box, the General tab and race lists, Salvation's new names, profiles loaded by
-- specialisation.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b, e) return a and b and math.abs(a - b) < (e or 0.6) end

local rawMeasure = MEASURE
MEASURE = function(path, size, text)
  text = tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return rawMeasure(path, size, text)
end
function PanelTemplates_TabResize(tab, padding, absoluteSize)
  if absoluteSize then tab:SetWidth(math.max(40, absoluteSize)) return end
  tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 20 + (padding or 0)))
end

S.class = "PRIEST"; S.locale = "enUS"; S.powerType = 0
S.mana, S.manaMax, S.health, S.healthMax = 1200, 3000, 900, 1500
S.knownSpells = { [6603] = true, [5019] = true, [1243] = true, [17] = true }
S.spec = 2; S.specNames = { "Discipline", "Holy", "Shadow" }
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
M.Frame(0.016)
local L, sv = ns.L, ns.sv
local ui = UIParent:GetEffectiveScale()

local function U(f) -- left, bottom, right, top in UIParent units
  M.ResetLayout()
  local l, b, w, h = M.AbsRect(f)
  return l / ui, b / ui, (l + w) / ui, (b + h) / ui
end
local function findButton(text)
  for _, f in ipairs(M.frames) do
    local fs = f.text or f._textFS or f.Text
    if fs and fs._text == text and f:IsVisible() then return f end
  end
end
local function goPage(n)
  for _, f in ipairs(M.frames) do
    if f.page == n and f._scripts and f._scripts.OnClick and f:IsVisible() then f._scripts.OnClick(f) return end
  end
end
local function under(f, root) while f do if f == root then return true end f = f._parent end return false end
local function boxesOf(page)
  local list = {}
  for _, f in ipairs(M.frames) do
    if M.IsGroupBox(f) and f:IsVisible() and under(f, page.back) then list[#list + 1] = f end
  end
  return list
end
local function overlap(list)
  for i = 1, #list do
    for j = i + 1, #list do
      local al, ab, ar, at = U(list[i]); local bl, bb, br, bt = U(list[j])
      if al < br - .5 and bl < ar - .5 and ab < bt - .5 and bb < at - .5 then return true end
    end
  end
  return false
end

ns:ShowOptions()
M.Frame(0.016)
local panel = _G.ClaraComboPointsOptions
local catalog = _G.ClaraComboPointsSpells
local body, sheet = panel.body, panel.sheet
local pages = {}
for _, f in ipairs(M.frames) do if f._parent == sheet and f._kind == "Frame" and f.back then pages[#pages + 1] = f end end
local wgrip, cgrip = panel.grip, catalog.grip

local function press(grip, button, dx, dy) -- dx, dy in UIParent units
  M.CursorOn(grip)
  M.mouseDown = true
  grip._scripts.OnMouseDown(grip, button)
  M.cursorX, M.cursorY = M.cursorX + (dx or 0) * ui, M.cursorY + (dy or 0) * ui
  M.Frame(0.016)
  M.mouseDown = false
  M.Frame(0.016)
end

out("== the window's corner, left button: its width and height")
local s0 = panel:GetScale()
local l0, _, _, t0 = U(panel)
check(near(panel:GetWidth(), 910) and near(panel:GetHeight(), 720), "default size 910 x 720")
press(wgrip, "LeftButton", -200 * s0, 150 * s0)
check(near(panel:GetWidth(), 710) and near(panel:GetHeight(), 570), ("dragged left and up: 710 x 570 (%.0f x %.0f)"):format(panel:GetWidth(), panel:GetHeight()))
local l1, _, _, t1 = U(panel)
check(near(l1, l0) and near(t1, t0) and near(panel:GetScale(), s0, .001), "its top left corner and its scale unchanged")
check(sv.window.w == 710 and sv.window.h == 570 and near(sv.window.scale, s0, .001), "kept: size, and the scale it had")
M.now = M.now + 1
press(wgrip, "LeftButton", -2000, 2000)
check(near(panel:GetWidth(), ns.MIN_WINDOW_W) and near(panel:GetHeight(), ns.MIN_WINDOW_H), "pushed far: at least " .. ns.MIN_WINDOW_W .. " x " .. ns.MIN_WINDOW_H)

out("== narrow: the right column under the left one, the pages scroll")
goPage(1)
local gen = pages[1]
local look
for _, b in ipairs(boxesOf(gen)) do if b.title and b.title._text == L.LOOK then look = b end end
local position -- (the first group: Scale; the position is above the class tabs)
for _, b in ipairs(boxesOf(gen)) do if b.title and b.title._text == L.SCALE then position = b end end
local ll, lb, lr, lt = U(look)
local pl, pb, pr, pt = U(position)
check(near(ll, pl, 1) and lt < pb, "General: Look under Scale and Opacity, at the left")
check(not overlap(boxesOf(gen)), "no group over another")
local vl, vb, vr, vt = U(body)
check(lr <= vr + .5, ("within the view's width (%.0f <= %.0f)"):format(lr, vr))
check(sheet:GetHeight() > body:GetHeight() + 1, ("taller than the view: it scrolls (%.0f > %.0f)"):format(sheet:GetHeight(), body:GetHeight()))
body:SetVerticalScroll(sheet:GetHeight() - body:GetHeight())
local _, lb2 = U(look)
check(lb2 >= vb - 13, "scrolled to the bottom: the last group in the view")
body:SetVerticalScroll(0)
-- every page: groups not over each other, within the view's width
for i = 1, 5 do
  goPage(i)
  local list = boxesOf(pages[i])
  local wide = 0
  for _, b in ipairs(list) do local _, _, r = U(b); wide = math.max(wide, r) end
  local _, _, viewR = U(body)
  check(#list > 0 and not overlap(list) and wide <= viewR + .5,
    ("page %d: %d groups, none over another, within the view (%.0f <= %.0f)"):format(i, #list, wide, viewR))
end
out("== the icons page, narrow: the rows' icons on two lines")
goPage(3)
local line
for _, f in ipairs(M.frames) do if f.Wrap and f:IsVisible() and f:GetHeight() > 30 then line = line or f end end
check(line ~= nil, "a row's line taller than one line of icons (" .. tostring(line and line:GetHeight()) .. ")")
ns.db.rows.above[1] = {}
for i = 1, 15 do ns.db.rows.above[1][i] = 1243 + (i > 1 and 100000 + i or 0) end
panel:Refresh()
local icons = {}
for _, f in ipairs(M.frames) do
  if f.landing and f.entry ~= nil and f:IsVisible() and f.index then
    local p = f:GetParent()
    if p.Wrap then icons[#icons + 1] = f end
  end
end
local firstLeft, lastLeft, firstTop, lastTop
for _, f in ipairs(icons) do
  local l, b, r, t = U(f)
  if f.index == 1 then firstLeft, firstTop = l, t end
  if f.index == 15 then lastLeft, lastTop = l, t end
end
check(firstTop and lastTop and lastTop < firstTop - 10, "the 15th icon on the next line down")
-- a drop on the second line lands there
do
  local lineFrame
  for _, f in ipairs(icons) do if f.index == 15 then lineFrame = f:GetParent() end end
  local per
  for _, f in ipairs(icons) do if f.index > 1 and not per then local _, _, _, t = U(f); if t < firstTop - 10 then per = f.index - 1 end end end
  check(per and per >= 5, "icons per line: " .. tostring(per))
end

out("== double click: back to the default size and scale")
M.now = M.now + 1
M.CursorOn(wgrip)
wgrip._scripts.OnMouseDown(wgrip, "LeftButton"); wgrip._scripts.OnMouseUp(wgrip)
M.now = M.now + .2
wgrip._scripts.OnMouseDown(wgrip, "LeftButton")
check(near(panel:GetWidth(), 910) and near(panel:GetHeight(), 720) and sv.window.w == nil and sv.window.scale == nil,
  ("910 x 720 again, its scale the one that fits the screen (%.0f x %.0f)"):format(panel:GetWidth(), panel:GetHeight()))
local l2, _, _, t2 = U(panel)
check(near(l2, l0) and near(t2, t0), "its top left corner where it was")
M.Frame(0.016)
check(near(panel:GetWidth(), 910), "no drag started by the double click")

out("== the right button still scales")
M.now = M.now + 1
press(wgrip, "RightButton", 910 * s0 * .1, -720 * s0 * .1)
check(near(panel:GetScale(), s0 * 1.1, .01) and near(panel:GetWidth(), 910), ("scaled 10 %% bigger, its size the same (%.3f -> %.3f)"):format(s0, panel:GetScale()))
ns:ResetWindowSize()

out("== the spells panel locked: its corner sizes its width and the height of both")
goPage(3)
check(catalog:IsShown() and sv.catalog.locked, "the panel beside the window, locked")
local cw0 = catalog:GetWidth()
M.now = M.now + 1
press(cgrip, "LeftButton", 100 * s0, 100 * s0)
check(near(catalog:GetWidth(), cw0 + 100) and near(panel:GetHeight(), 620) and near(catalog:GetHeight(), 620),
  ("wider by 100, both 100 shorter (%.0f, %.0f / %.0f)"):format(catalog:GetWidth(), panel:GetHeight(), catalog:GetHeight()))
local _, _, wr, wt = U(panel)
local cl, _, _, ct = U(catalog)
check(near(cl, wr) and near(ct, wt), "still at the window's top right")
M.now = M.now + 1
press(cgrip, "LeftButton", 0, 0); M.now = M.now + .1
M.CursorOn(cgrip); cgrip._scripts.OnMouseDown(cgrip, "LeftButton")
check(near(catalog:GetWidth(), 420) and near(panel:GetHeight(), 720), "double click: both back to their default size")

out("== locked again on the left of the window: it stays on the left")
local lock = catalog.lock
lock:Click()
check(not sv.catalog.locked, "unlocked")
-- dragged left of the window
local wl, wb, wr2, wt2 = U(panel)
sv.catalog.left, sv.catalog.top = wl - 500, wt2
ns:SetCatalogLocked(false) -- (placed again where it is now)
catalog:ClearAllPoints(); catalog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (wl - 500) / (sv.catalog.scale / 1), wt2 / sv.catalog.scale)
M.ResetLayout()
lock:Click()
local cl2, _, cr2, ct2 = U(catalog)
check(sv.catalog.locked and sv.catalog.side == "left" and near(cr2, wl) and near(ct2, wt2),
  ("locked: against the window's left side (%.0f / %.0f)"):format(cr2, wl))
-- its corner: the panel's top left stays, the window moves right with its width
local cl3 = cl2
M.now = M.now + 1
press(cgrip, "LeftButton", 60 * s0, 0)
local cl4, _, cr4 = U(catalog)
local wl4 = U(panel)
check(near(cl4, cl3) and near(cr4 - cl4, (420 + 60) * s0, 1) and near(wl4, cr4), "wider: its left side in place, the window pushed right")
ns:ResetWindowSize(true)
-- unlocked and locked again on the right of the window
lock:Click()
local wl5, _, wr5, wt5 = U(panel)
catalog:ClearAllPoints(); catalog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (wr5 + 300) / sv.catalog.scale, wt5 / sv.catalog.scale)
local cs = sv.catalog.scale
sv.catalog.left, sv.catalog.top = wr5 + 300, wt5
M.ResetLayout()
lock:Click()
local cl6 = U(catalog)
check(sv.catalog.side == nil and near(cl6, wr5), "locked from the right of the window: on its right again")

out("== the panel on its own: its corner sizes it alone")
lock:Click()
local before = { U(panel) }
local fw, fh = catalog:GetWidth(), catalog:GetHeight()
M.now = M.now + 1
press(cgrip, "LeftButton", 80 * sv.catalog.scale, 50 * sv.catalog.scale)
local after = { U(panel) }
check(near(catalog:GetWidth(), fw + 80) and near(catalog:GetHeight(), fh - 50) and sv.catalog.w == math.floor(fw + 80 + .5),
  ("the panel 80 wider, 50 shorter (%.0f x %.0f)"):format(catalog:GetWidth(), catalog:GetHeight()))
check(near(before[1], after[1]) and near(before[3], after[3]) and near(before[2], after[2]), "the window unchanged")
lock:Click()

out("== show only known spells")
local knownBox = catalog.knownOnly
check(knownBox and knownBox:IsVisible() and not knownBox.check:GetChecked(), "a box at the top of the panel, off")
local function shownGroups()
  local list = {}
  for _, g in ipairs(catalog.groups) do if g.head:IsShown() then list[#list + 1] = g.class end end
  return table.concat(list, ",")
end
local function unfolded()
  local list = {}
  for _, g in ipairs(catalog.groups) do
    if g.head:IsShown() and g.head.sign._file == "Interface\\Buttons\\UI-MinusButton-Up" then list[#list + 1] = g.class end
  end
  return table.concat(list, ",")
end
local all = shownGroups()
check(all:find("GENERAL", 1, true) and all:find("HUMAN", 1, true) and all:find("SKYBORNE_HORDE", 1, true),
  "the General tab and every race listed after the classes: " .. all)
knownBox.check:Click()
check(sv.catalog.knownOnly == true, "ticked: kept")
check(shownGroups() == all, "every list still there: " .. shownGroups())
check(unfolded() == "PRIEST,GENERAL", "unfolded: only the lists with a spell the character knows: " .. unfolded())
local rogue
for _, g in ipairs(catalog.groups) do if g.class == "ROGUE" then rogue = g end end
local rogueTotal = #rogue.recs
rogue.head:Click()
local shownRows = 0
for _, row in ipairs(rogue.rows) do if row:IsShown() then shownRows = shownRows + 1 end end
check(unfolded() == "PRIEST,ROGUE,GENERAL" and shownRows == rogueTotal and rogue.count._text == tostring(rogueTotal),
  "a folded list without known spells unfolds with all its spells (" .. shownRows .. " of " .. rogueTotal .. ")")
rogue.head:Click()
local general
for _, g in ipairs(catalog.groups) do if g.class == "GENERAL" then general = g end end
check(general.count._text == "2", "General: Attack and Shoot (" .. tostring(general.count._text) .. ")")
knownBox.check:Click()
check(sv.catalog.knownOnly == nil and shownGroups() == all, "unticked: every list again")
-- a Windshaper (Horde) Skyborne: only the Windshaper list, with known spells only
S.faction = "Horde"
S.knownSpells[1259686] = true; S.knownSpells[1259416] = true
knownBox.check:Click()
check(unfolded() == "PRIEST,GENERAL,SKYBORNE_HORDE", "a Horde Skyborne: the Windshaper list unfolded, not the High Order one: " .. unfolded())
S.faction = "Alliance"; S.knownSpells[1259686] = nil; S.knownSpells[1259705] = true
knownBox.check:Click(); knownBox.check:Click()
check(unfolded() == "PRIEST,GENERAL,SKYBORNE_ALLIANCE", "an Alliance Skyborne: the High Order list unfolded: " .. unfolded())
knownBox.check:Click()
S.knownSpells[1259705] = nil; S.knownSpells[1259416] = nil
SlashCmdList.CLARARELOAD("")
check(M.reloaded == 1, "/rl reloads the interface")
local walk = 0
for _, g in ipairs(catalog.groups) do
  for _, rec in ipairs(g.recs) do if rec.ranks and rec.ranks[1][2] == 1259416 then walk = walk + 1 end end
end
check(walk == 2, "Walk on Air in both Skyborne lists, each its own line (" .. walk .. ")")
local labels = {}
for _, g in ipairs(catalog.groups) do
  for _, r in ipairs(M.regions) do
    if r._parent == g.head and r._kind == "FontString" and r._fontObject == "GameFontNormal" then labels[g.class] = r._text end
  end
end
check(labels.HUMAN == "Human racial abilities" and labels.SKYBORNE_HORDE == "Skyborne (Windshaper) racial abilities"
  and labels.GENERAL == "General" and labels.PRIEST == "Priest", "races named with their racial abilities: " .. tostring(labels.HUMAN))

out("== Salvation's new names")
local rec = ns:CatalogRecord(1038)
check(rec and rec.names[1] == "Salvation" and ns:CatalogMatches(rec, ns:SearchKey("blessing of salvation"))
  and ns:CatalogMatches(rec, ns:SearchKey("bénédiction de salut")), "Salvation: found by its old names too")
local mass = ns:CatalogRecord(25895)
check(mass and mass.names[1] == "Mass Salvation" and ns:CatalogMatches(mass, ns:SearchKey("greater blessing")), "Mass Salvation")

out("== profiles loaded by specialisation")
local function flush() for _ = 1, 20 do if #M.timers == 0 then return end M.RunTimer() end end
goPage(5)
local specBox
for _, f in ipairs(M.frames) do
  if f.check and f:IsVisible() and f.check.Text and tostring(f.check.Text._text):find("Holy", 1, true) then specBox = f end
end
check(specBox ~= nil, "on the priest's tab: Load it in my specialization (Holy)")
ns.db.fontSize = 22
-- type a name, tick, save
local nameBox
for _, f in ipairs(M.frames) do if f._kind == "EditBox" and f:IsVisible() and f:GetMaxLetters() == 32 then nameBox = f end end
nameBox:SetText("Raid")
specBox.check:Click()
findButton(L.PROFILE_SAVE):Click()
check(ns:SpecProfile("PRIEST", 2) == "Raid" and sv.specs.PRIEST[2] == "Raid", "saved as Holy's profile")
check(findButton(L.PROFILE_SAVE) and ns:SpecProfilesText("PRIEST"):find("Holy", 1, true), "the page says which: " .. ns:SpecProfilesText("PRIEST"))
ns.db.fontSize = 14
nameBox:SetText("Solo")
specBox.check:SetChecked(false)
findButton(L.PROFILE_SAVE):Click()
check(ns:SpecProfile("PRIEST", 2) == "Raid", "another profile saved without the box: Holy keeps Raid")
-- Shadow: Solo
S.spec = 3
M.Fire("PLAYER_SPECIALIZATION_CHANGED", "player"); flush()
check(ns:ActiveProfile("PRIEST") == "Solo", "Shadow has no profile: nothing loaded")
nameBox:SetText("Solo"); nameBox:GetScript("OnTextChanged")(nameBox)
specBox.check:Click()
check(ns:SpecProfile("PRIEST", 3) == "Solo", "the box ticked on a saved profile: tied at once")
-- back to Holy: Raid loads
M.sent = {}
S.spec = 2
M.Fire("ACTIVE_TALENT_GROUP_CHANGED"); flush()
check(ns:ActiveProfile("PRIEST") == "Raid" and ns.db.fontSize == 22, "Holy again: Raid loaded (font 22)")
S.spec = 3
M.Fire("PLAYER_TALENT_UPDATE"); flush()
check(ns:ActiveProfile("PRIEST") == "Solo" and ns.db.fontSize == 14, "Shadow: Solo loaded (font 14)")
ns.db.fontSize = 30 -- Solo changed, not saved
S.spec = 2
M.Fire("PLAYER_SPECIALIZATION_CHANGED", "player"); flush()
check(ns:ActiveProfile("PRIEST") == "Raid" and ns.sv.saved.PRIEST.Solo.fontSize == 30, "its changes kept in Solo before Raid loads")
ns:DeleteProfile("PRIEST", "Solo")
check(ns:SpecProfile("PRIEST", 3) == nil, "a profile deleted: no longer tied")

out(fails .. " failure(s)")
return fails > 0
