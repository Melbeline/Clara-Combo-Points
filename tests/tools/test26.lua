-- the newest options features: the specialisations menu on the portrait (right-click), the
-- battleground hide rule, the spells panel's lock (attached to the window or on its own, moved
-- and sized alone, its place kept across closing and a reload) and the look of the groups (the
-- character sheet's bronze border, or the tooltip border in bronze without that atlas)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b, e) return a and b and math.abs(a - b) < (e or 0.01) end

-- The game's tabs as the client draws them (as test25): exactly absoluteSize wide, and a
-- text's colour escapes take no room.
local rawMeasure = MEASURE
MEASURE = function(path, size, text)
  text = tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return rawMeasure(path, size, text)
end
function PanelTemplates_TabResize(tab, padding, absoluteSize)
  if absoluteSize then tab:SetWidth(math.max(40, absoluteSize)) return end
  tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 20 + (padding or 0)))
end

-- saved: specialisation icons, some of them bad (an index past the class's specs, not whole, a
-- string, 0, negative, infinite, NaN, a class that does not exist)
ClaraComboPointsDB = { profiles = {}, portraitsVersion = 2, portraits = { DRUID = 9, ROGUE = 2.5, WARRIOR = "1", MAGE = 0, PRIEST = -1,
  SHAMAN = 1 / 0, PALADIN = 0 / 0, HUNTER = 3, WARLOCK = 2, FOO = 1 } }
local ns = {}
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3 -- Cat Form
S.mana, S.manaMax, S.health, S.healthMax = 1200, 3000, 900, 1500
S.target = { cp = 2, hostile = true }; S.energy = 60; S.rage = 30
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
M.Frame(0.016)
local L, sv = ns.L, ns.sv
local LANGS = { "enUS", "frFR", "deDE" }
local CLASSES = { "PRIEST", "MAGE", "WARLOCK", "DRUID", "ROGUE", "HUNTER", "SHAMAN", "PALADIN", "WARRIOR" }
local ICON_DIR = "Interface\\Icons\\"
local LOCK = "Interface\\Buttons\\LockButton-"
local PANEL_W, PANEL_H, SIDE_W = 910, 720, 420
local ui = UIParent:GetEffectiveScale()

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function strip(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function label(f)
  if f.text and f.text._text then return f.text._text end
  if f._textFS then return f._textFS._text end
end
local function descends(r, root)
  local f = r
  while f do
    if f == root then return true end
    f = f._parent
  end
  return false
end
local function findButton(text, root)
  for _, f in ipairs(M.frames) do
    if (f._kind == "Button" or f._kind == "CheckButton") and f:IsVisible() and label(f) == text and (not root or descends(f, root)) then return f end
  end
end
local function findCheck(text, root)
  for _, f in ipairs(M.frames) do
    if f._kind == "CheckButton" and f:IsVisible() and f.Text and f.Text._text == text and (not root or descends(f, root)) then return f end
  end
end
local function shownText(text, root)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text == text and r:IsVisible() and (not root or descends(r, root)) then return r end
  end
end
-- left, bottom, right, top: on the screen (absolute), in UIParent units
local function A(r) M.ResetLayout(); local l, b, w, h = M.AbsRect(r); return l, b, l + w, b + h end
local function U(r) local l, b, rt, t = A(r); return l / ui, b / ui, rt / ui, t / ui end
local function sameRect(a, b, e)
  e = e or 0.5
  for i = 1, 4 do if not near(a[i], b[i], e) then return false end end
  return true
end
local function fmt(r) return ("%.1f %.1f %.1f %.1f"):format(r[1], r[2], r[3], r[4]) end
local function deepcopy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[deepcopy(k)] = deepcopy(x) end
  return t
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

-- the window and what is in it (again after a reload)
local panel, catalog, lock, cgrip, wgrip, pb, menu, portrait
local tabs, navs, pages = {}, {}, {}
local function open()
  if not (panel and panel:IsShown()) then SlashCmdList.CLARACOMBOPOINTS("") end
  panel = ClaraComboPointsOptions
  catalog = ClaraComboPointsSpells
  lock, cgrip, wgrip = catalog.lock, catalog.grip, panel.grip
  pb, menu = panel.portraitButton, panel.specMenu
  portrait = panel.PortraitContainer.portrait
  tabs, navs, pages = {}, {}, {}
  for _, f in ipairs(M.frames) do
    if descends(f, panel) then
      if f.class and f.isTopTab then tabs[f.class] = f end
      if f._kind == "Button" and f.page and f.name and f.desc then navs[f.page] = f end
      if f._parent == panel.sheet and f._kind == "Frame" and f.back then pages[#pages + 1] = f end
    end
  end
end
local function press(b) -- a real click: the press, then the click
  if b._scripts and b._scripts.OnMouseDown then b._scripts.OnMouseDown(b, "LeftButton") end
  b:Click()
end
local function goPage(n) press(navs[n]) end
local function tab(class) tabs[class]:Click() end
-- a /reload: the saved variables written (and read back) as the game does, the addon loaded
-- again from them. change(db): edits the saved variables in between.
local function reload(change)
  if panel and panel:IsShown() then panel:Hide() end
  M.Fire("PLAYER_LOGOUT")
  local saved = deepcopy(ClaraComboPointsDB)
  if change then change(saved) end
  if ns.hud then ns.hud:Hide() end
  M.eventFrames = {}
  ns = {}
  ClaraComboPointsDB = saved
  M.LoadAddon(ADDON_DIR, ns)
  M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
  M.Frame(0.016)
  L, sv = ns.L, ns.sv
  panel, catalog = nil, nil
end
-- each language's own strings (not the English fallback)
local function strings()
  local fn = getmetatable(L).__index
  for i = 1, 10 do
    local name, v = debug.getupvalue(fn, i)
    if name == "strings" then return v end
    if not name then break end
  end
end

---------------------------------------------------------------------------
out("== saved specialisation icons, cleaned at load")
check(sv.portraits.HUNTER == 3 and sv.portraits.WARLOCK == 2, "valid picks kept (hunter 3, warlock 2)")
do
  local left = {}
  for k, v in pairs(sv.portraits) do if k ~= "HUNTER" and k ~= "WARLOCK" then left[#left + 1] = k .. "=" .. tostring(v) end end
  check(#left == 0, "the bad ones dropped (" .. (#left > 0 and table.concat(left, " ") or "none left") .. ")")
end
do
  local shape, classes = true, 0
  for _, class in ipairs(CLASSES) do
    local specs = ns.SPECS[class]
    if specs then classes = classes + 1 end
    local want = class == "DRUID" and 4 or 3
    if not specs or #specs ~= want then shape = false; out("    " .. class .. ": " .. tostring(specs and #specs)) end
    local seen = {}
    for _, icon in ipairs(specs or {}) do
      if type(icon) ~= "string" or icon:find("\\", 1, true) or seen[icon] then shape = false end
      seen[icon] = true
    end
  end
  check(shape and classes == 9 and count(ns.SPECS) == 9, "ns.SPECS: the nine classes, four specialisations for the druid, three for the others, each icon once")
end

---------------------------------------------------------------------------
out("== the portrait: its button, its icon")
open()
check(panel:IsShown() and pb and menu and pb:GetParent() == panel and menu:GetParent() == panel, "a button over the portrait, and its menu (in the window)")
do
  local a, b = { A(pb) }, { A(portrait) }
  check(sameRect(a, b), "the button covers the portrait (" .. fmt(a) .. " / " .. fmt(b) .. ")")
end
check(pb:GetFrameLevel() > panel.PortraitContainer:GetFrameLevel(), "above the portrait's frame")
check(pb._clicks and #pb._clicks == 1 and pb._clicks[1] == "RightButtonUp", "clicked with the right button only")
check(portrait._file == ICON_DIR .. "Ability_Druid_CatForm", "the druid tab: the class's own icon, the bad saved pick dropped (" .. tostring(portrait._file) .. ")")
check(not menu:IsShown(), "the menu closed when the window opens")

local function rightClick()
  M.CursorOn(pb)
  M.Fire("GLOBAL_MOUSE_DOWN", "RightButton")
  M.Press(pb, "RightButton")
end
local function shownRows()
  local list = {}
  for _, r in ipairs(menu.rows) do if r:IsShown() then list[#list + 1] = r end end
  return list
end
local function litRows()
  local list = {}
  for i, r in ipairs(menu.rows) do if r:IsShown() and r.bg:IsShown() then list[#list + 1] = i end end
  return table.concat(list, ",")
end

out("== a right-click: the class's specialisations")
rightClick()
check(menu:IsShown() and menu._strata == "FULLSCREEN_DIALOG", "open, over the window and the spells panel (FULLSCREEN_DIALOG strata)")
do
  local ml, mb, mr, mt = A(menu)
  local pl, pbm, pr, pt = A(portrait)
  local s = panel:GetEffectiveScale()
  check(mt <= pbm + 8 * s + 0.5 and mt >= pbm - 0.5 and ml >= pl and ml <= pr, "under the portrait (menu top-left at "
    .. ("%.0f, %.0f; portrait %.0f-%.0f, bottom %.0f"):format(ml, mt, pl, pr, pbm) .. ")")
  local wl, wb, wr, wt = A(panel)
  check(ml >= wl and mr <= wr and mb >= wb, "inside the window")
end
check(M.IsGroupBox(menu), "in the look of the window's groups")
check(menu._events and menu._events.GLOBAL_MOUSE_DOWN, "open: it listens to the mouse presses")
-- A popup over other texts: its background must hide them (a group box's fill, 55 % black,
-- lets the class tabs and the list of pages under it show through its names).
local function menuFillAlpha()
  if menu._bdColor then return menu._bdColor[4] or 1 end
  for _, r in ipairs(M.regions) do
    if r._parent == menu and r._kind == "Texture" and r._layer == "BACKGROUND" and r._color then return r._color[4] end
  end
  return 0
end
local function intersects(a, b) return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4] end
do
  local under = {}
  local m = { A(menu) }
  for _, class in ipairs(CLASSES) do if intersects(m, { A(tabs[class]) }) then under[#under + 1] = strip(tabs[class].Text._text) end end
  for i = 1, 5 do if navs[i]:IsVisible() and intersects(m, { A(navs[i]) }) then under[#under + 1] = strip(navs[i].name._text) end end
  local alpha = menuFillAlpha()
  check(alpha >= .9, ("its background hides what is under it (%s): opacity %.0f %%"):format(table.concat(under, ", "), alpha * 100))
end
-- the portrait's button (over the frame's art) must not take the clicks of the class tabs
do
  local l, b, r, t = A(pb)
  local s = panel:GetEffectiveScale()
  local hit = pb._hit or { 0, 0, 0, 0 }
  local box = { l + hit[1] * s, b + hit[4] * s, r - hit[2] * s, t - hit[3] * s }
  local over = {}
  for _, class in ipairs(CLASSES) do
    local tr = { A(tabs[class]) }
    if intersects(box, tr) then over[#over + 1] = ("%s (%.0f px)"):format(strip(tabs[class].Text._text), (box[4] > tr[4] and tr[4] - box[2] or box[4] - box[2]) / s) end
  end
  check(#over == 0, "the portrait's click area clear of the class tabs" .. (#over > 0 and (" (over the top of " .. table.concat(over, ", ") .. ")") or ""))
end

local strs = strings()
local NAMES = {
  enUS = { DRUID = { "Balance", "Feral", "Guardian", "Restoration" }, WARRIOR = { "Arms", "Fury", "Protection" },
    ROGUE = { "Assassination", "Combat", "Subtlety" } },
  frFR = { DRUID = { "Équilibre", "Farouche", "Gardien", "Restauration" }, WARRIOR = { "Armes", "Fureur", "Protection" },
    ROGUE = { "Assassinat", "Combat", "Finesse" } },
  deDE = { DRUID = { "Gleichgewicht", "Wildheit", "Wächter", "Wiederherstellung" }, WARRIOR = { "Waffen", "Furor", "Schutz" },
    ROGUE = { "Meucheln", "Kampf", "Täuschung" } },
}
-- the row lit by default: the one wearing the class's own icon (none for some), or the saved pick
local LIT = { PRIEST = "1", MAGE = "3", WARLOCK = "2", DRUID = "2", ROGUE = "1", HUNTER = "3", SHAMAN = "", PALADIN = "1", WARRIOR = "" }
for _, lang in ipairs(LANGS) do
  ns:SetLanguage(lang)
  local rowsOK, namesOK, litOK, fitOK, own, spot = true, true, true, true, true, true
  local problems = {}
  for _, class in ipairs(CLASSES) do
    tab(class)
    if menu:IsShown() then menu:Hide() end
    rightClick()
    local specs = ns.SPECS[class]
    local rows = shownRows()
    if #rows ~= #specs then rowsOK = false; problems[#problems + 1] = class .. ": " .. #rows .. " rows" end
    local seen = {}
    for i, r in ipairs(rows) do
      if r ~= menu.rows[i] or r.icon._file ~= ICON_DIR .. specs[i] then rowsOK = false; problems[#problems + 1] = class .. " " .. i .. ": " .. tostring(r.icon._file) end
      local key = "SPEC_" .. class .. "_" .. i
      local name = r.name._text
      if type(name) ~= "string" or name == "" or name ~= L[key] or seen[name] then namesOK = false; problems[#problems + 1] = class .. " " .. i .. ": " .. tostring(name) end
      seen[name or ""] = true
      if not (strs and strs[lang] and strs[lang][key]) then own = false; problems[#problems + 1] = lang .. " has no " .. key end
      if NAMES[lang][class] and NAMES[lang][class][i] ~= name then spot = false; problems[#problems + 1] = class .. " " .. i .. ": " .. tostring(name) end
    end
    local lit = litRows()
    if lit ~= LIT[class] then litOK = false; problems[#problems + 1] = class .. " lit: " .. lit .. " (want " .. LIT[class] .. ")" end
    -- every row inside the menu, its icon and name inside it, one under the other
    local E = 0.5
    local ml, mb, mr, mt = A(menu)
    local prevBottom
    for i, r in ipairs(rows) do
      local rl, rb, rr_, rt = A(r)
      local il, ib, ir, it = A(r.icon)
      local nl, nb, nr, nt = A(r.name)
      local bad
      if rl < ml - E or rr_ > mr + E or rb < mb - E or rt > mt + E then bad = "row outside the menu" end
      if il < rl - E or ir > rr_ + E or ib < rb - E or it > rt + E then bad = "icon outside its row" end
      if nl < ir - E or nr > rr_ - 2 + E or nb < rb - E or nt > rt + E then bad = ("name outside its row (%.0f > %.0f)"):format(nr, rr_ - 2) end
      if prevBottom and rt > prevBottom + E then bad = "row over the one above" end
      if bad then fitOK = false; problems[#problems + 1] = ("%s %s: %s (%s)"):format(class, i, bad, strip(r.name._text)) end
      prevBottom = rb
    end
    if prevBottom and (prevBottom - mb > 14 * panel:GetEffectiveScale() or prevBottom < mb - E) then
      fitOK = false; problems[#problems + 1] = class .. ": the menu not ending under its last row"
    end
    menu:Hide()
  end
  for i = 1, math.min(#problems, 10) do out("    " .. problems[i]) end
  check(rowsOK, lang .. ": one row per specialisation of each class (druid 4, the others 3), each with its icon")
  check(namesOK and own, lang .. ": each row named in the language (L.SPEC_<CLASS>_<i>, in the language's own strings)")
  check(spot, lang .. ": the druid's, the warrior's and the rogue's names as translated")
  check(litOK, lang .. ": the icon worn lit (druid: Feral, the cat form; warrior: none; saved picks: hunter 3, warlock 2)")
  check(fitOK, lang .. ": the menu fits its longest name, every row inside it")
end
ns:SetLanguage("enUS")

out("== picking a specialisation")
tab("DRUID")
rightClick()
do
  local r3 = menu.rows[3]
  M.CursorOn(r3)
  M.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  check(menu:IsShown(), "a press on the menu leaves it open")
  r3:Click()
  check(sv.portraits.DRUID == 3 and portrait._file == ICON_DIR .. ns.SPECS.DRUID[3] and not menu:IsShown(),
    "Guardian picked: saved (sv.portraits.DRUID = " .. tostring(sv.portraits.DRUID) .. "), the portrait wears it, the menu closed")
  check(not (menu._events and menu._events.GLOBAL_MOUSE_DOWN), "closed: no longer listening to the mouse")
  rightClick()
  check(litRows() == "3", "opened again: Guardian lit (" .. litRows() .. ")")
  menu:Hide()
end
tab("WARRIOR")
check(portrait._file == ICON_DIR .. "Ability_Warrior_BattleShout", "the Warrior tab: its own icon (" .. tostring(portrait._file) .. ")")
rightClick()
check(litRows() == "", "none of its specialisations lit")
menu.rows[2]:Click()
check(sv.portraits.WARRIOR == 2 and portrait._file == ICON_DIR .. ns.SPECS.WARRIOR[2], "Fury picked: the warrior's portrait")
tab("DRUID")
check(portrait._file == ICON_DIR .. ns.SPECS.DRUID[3] and sv.portraits.DRUID == 3, "back on the druid: its own pick (Guardian)")
tab("SHAMAN")
check(portrait._file == ICON_DIR .. "Spell_Nature_BloodLust", "a tab never picked: the class's icon")
tab("DRUID")
check(sv.profiles.DRUID.portraits == nil and sv.profiles.DRUID.portrait == nil, "account-wide (not in the class's profile)")

out("== closing the menu")
rightClick()
M.CursorOn(pb)
M.Fire("GLOBAL_MOUSE_DOWN", "RightButton")
check(menu:IsShown(), "a press on the portrait leaves it open (the click decides)")
M.Press(pb, "RightButton")
check(not menu:IsShown(), "a second right-click on the portrait closes it")
rightClick()
M.CursorOn(navs[2])
M.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
check(not menu:IsShown(), "a press elsewhere closes it")
rightClick()
M.CursorOn(menu)
M.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
check(menu:IsShown(), "a press on the menu itself does not")
tab("ROGUE")
check(not menu:IsShown(), "another tab closes it")
tab("DRUID")
rightClick()
panel:Hide()
check(not menu:IsShown(), "closing the window closes it")
open()
check(not menu:IsShown(), "opened again: the menu stays closed")

out("== the portrait's tooltip, its drag")
for _, lang in ipairs(LANGS) do
  ns:SetLanguage(lang)
  pb._scripts.OnEnter(pb)
  local want = ({ enUS = "Right-click: change the icon (specialization)", frFR = "Clic droit : changer l'icône (spécialisation)",
    deDE = "Rechtsklick: Symbol ändern (Spezialisierung)" })[lang]
  check(GameTooltip._shown and GameTooltip:IsOwned(pb) and GameTooltip._lines[1] == L.PORTRAIT_TIP and L.PORTRAIT_TIP == want,
    lang .. ": hovered, a tooltip says what the right-click does (" .. tostring(GameTooltip._lines and GameTooltip._lines[1]) .. ")")
  pb._scripts.OnLeave(pb)
  check(not GameTooltip._shown, lang .. ": gone when the cursor leaves")
end
ns:SetLanguage("enUS")
pb._scripts.OnEnter(pb)
rightClick()
check(not GameTooltip._shown and menu:IsShown(), "the right-click hides the tooltip")
pb._scripts.OnEnter(pb)
check(not GameTooltip._shown, "no tooltip over the open menu's portrait")
menu:Hide()
do
  local s = panel:GetScale()
  pb._scripts.OnDragStart(pb)
  check(panel._moving == true, "a left drag on the portrait moves the window")
  panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 300, 900) -- where the game puts it
  pb._scripts.OnDragStop(pb)
  check(panel._moving == false and near(sv.window.left, 300 * s, .5) and near(sv.window.top, 900 * s, .5),
    ("let go: the window's place kept (%.0f, %.0f)"):format(sv.window.left or -1, sv.window.top or -1))
  check(not menu:IsShown(), "no menu opened by the drag")
end

---------------------------------------------------------------------------
out("== hidden in a battleground")
panel:Hide()
do
  local db = sv.profiles.DRUID
  local function zone(kind, extra)
    S.instance = kind and { kind = kind, maxPlayers = extra } or nil
    M.Fire("ZONE_CHANGED_NEW_AREA")
  end
  S.group = nil
  zone("pvp")
  local now = ns:Situation()
  check(now.battleground and now.solo and not now.dungeon and not now.raid10 and not now.raid20 and not now.raid40,
    "IsInInstance(): true, \"pvp\": in a battleground (and alone)")
  check(db.hideWhen.battleground == false, "the rule off by default")
  check(ns.hud:IsShown(), "not ticked: the HUD shows in the battleground")
  ns:SetHideWhen("battleground", true)
  check(db.hideWhen.battleground == true and not ns.hud:IsShown(), "ticked: hidden in the battleground")
  zone(nil)
  check(not ns:Situation().battleground and ns.hud:IsShown(), "out of it: shown again")
  S.instance = { kind = "pvp" }; M.Fire("PLAYER_ENTERING_WORLD")
  check(not ns.hud:IsShown(), "back in (the loading screen): hidden")
  zone("party", 5)
  check(ns:Situation().dungeon and not ns:Situation().battleground and ns.hud:IsShown(), "a dungeon is no battleground: shown")
  zone("raid", 40)
  check(ns:Situation().raid40 and not ns:Situation().battleground and ns.hud:IsShown(), "nor a raid")
  S.group = "raid"; zone("pvp")
  check(ns:Situation().raid and ns:Situation().battleground and not ns.hud:IsShown(), "in a raid group in the battleground: hidden")
  open()
  check(ns.hud:IsShown(), "the options open: shown, to be set up")
  goPage(4)
  local showBox = findCheck(L.SHOW_ADDON, pages[4])
  check(showBox and showBox:GetChecked() == false, "the Show the addon box: unticked while the battleground hides it")
  panel:Hide()
  check(not ns.hud:IsShown(), "closed: hidden again")
  ns:SetLocked(false)
  check(ns.hud:IsShown(), "the bar unlocked: shown, to be moved")
  ns:SetLocked(true)
  check(not ns.hud:IsShown(), "locked again: hidden")
  ns:SetHidden(false) -- the Show box ticked anyway (or /cl show)
  check(ns.hud:IsShown(), "shown by hand against the rule: shown")
  zone(nil); zone("pvp")
  check(not ns.hud:IsShown(), "the next battleground: the rule again")
  ns:SetHideWhen("battleground", false)
  check(db.hideWhen.battleground == false and ns.hud:IsShown(), "unticked: shown in the battleground")
  S.group = nil; zone(nil)
end

out("== the Battleground box: fifth of the Zone column")
open()
goPage(4)
for _, lang in ipairs(LANGS) do
  ns:SetLanguage(lang)
  local want = ({ enUS = "Battleground", frFR = "Champ de bataille", deDE = "Schlachtfeld" })[lang]
  local col = {}
  for i, key in ipairs({ "dungeon", "raid10", "raid20", "raid40", "battleground" }) do col[i] = findCheck(L["HIDE_" .. key:upper()], pages[4]) end
  local bg = col[5]
  check(bg and L.HIDE_BATTLEGROUND == want, lang .. ": a box named " .. tostring(L.HIDE_BATTLEGROUND))
  if bg then
    local inColumn = true
    local bl, bb, br, bt = A(bg)
    for i = 1, 4 do
      local c = col[i]
      local l, b, r, t = A(c)
      local s = panel:GetEffectiveScale()
      if not near(l, bl, .5) then inColumn = false end
      if not near(t - bt, (5 - i) * 22 * s, .5) then inColumn = false; out(("    %s: %.1f above"):format(L["HIDE_" .. ({ "DUNGEON", "RAID10", "RAID20", "RAID40" })[i]], (t - bt) / s)) end
    end
    check(inColumn, lang .. ": under Raid (40), the fifth of the Zone column, 22 apart")
    local box
    for _, f in ipairs(M.frames) do
      if M.IsGroupBox(f) and f:IsVisible() and descends(f, pages[4].back) and f.title and f.title._text == L.HIDE_WHEN then box = f end
    end
    local hint = shownText(L.HIDE_HINT, pages[4])
    local xl, xb, xr, xt = A(box)
    local ll, lb, lr, lt = A(bg.Text)
    local hl, hb, hr, ht = A(hint)
    local s = panel:GetEffectiveScale()
    check(box and bl >= xl and lr <= xr - 4 * s and bb >= xb and lb >= xb, lang .. ": inside the Hide it when group (its name too)")
    check(hint and ht <= math.min(bb, lb) + 0.5 and hb >= xb, lang .. ": the hint below it, still in the group")
  end
end
ns:SetLanguage("enUS")
do
  local bg = findCheck(L.HIDE_BATTLEGROUND, pages[4])
  bg:Click()
  check(sv.profiles.DRUID.hideWhen.battleground == true and bg:GetChecked(), "clicked: the druid's rule on")
  tab("ROGUE")
  check(findCheck(L.HIDE_BATTLEGROUND, pages[4]):GetChecked() == false and sv.profiles.ROGUE.hideWhen.battleground == false, "the Rogue tab: its own rule, off")
  tab("DRUID")
  bg:Click()
  check(sv.profiles.DRUID.hideWhen.battleground == false and not bg:GetChecked(), "clicked again: off")
end

---------------------------------------------------------------------------
out("== the spells panel: locked beside the window by default")
check(sv.catalog.locked == true and sv.catalog.left == nil and sv.catalog.top == nil and sv.catalog.scale == nil, "sv.catalog = { locked = true }")
goPage(3)
local function attached()
  local cl, cb, cr, ct = A(catalog)
  local pl, pbm, pr, pt = A(panel)
  local p1, rel = catalog:GetPoint(1)
  return catalog:IsShown() and near(catalog:GetScale(), 1) and rel == panel and near(cl, pr, .5) and near(ct, pt, .5)
end
check(catalog:IsShown() and attached(), "on the Icons page: at the window's top right, scale 1")
check(lock and lock:IsVisible() and lock:GetParent() == catalog, "a lock on the panel")
do
  local ll, lb, lr, lt = A(lock)
  local cl, cb, cr, ct = A(catalog)
  local title = catalog.TitleContainer.TitleText
  local tl, tb, tr, tt = A(catalog.TitleContainer)
  local tw = title:GetStringWidth() * catalog:GetEffectiveScale()
  local textLeft = (tl + tr) / 2 - tw / 2
  check(ll >= cl and lt <= ct + 0.5 and lb >= ct - 26 * catalog:GetEffectiveScale() and lr < textLeft,
    ("in its title bar, left of the title (lock %.0f-%.0f, title from %.0f)"):format(ll, lr, textLeft))
  check(lock:GetFrameLevel() > catalog.TitleContainer:GetFrameLevel(), "over the title bar's art")
end
local function lockArt(state) return lock._normalTex == LOCK .. state .. "-Up" and lock._pushedTex == LOCK .. "Unlocked-Down" end -- (no Locked-Down file)
check(lockArt("Locked"), "closed padlock (" .. tostring(lock._normalTex) .. ")")
for _, lang in ipairs(LANGS) do
  ns:SetLanguage(lang)
  lock._scripts.OnEnter(lock)
  check(GameTooltip:IsOwned(lock) and GameTooltip._lines[1] == L.CATALOG_LOCKED and GameTooltip._lines[2] == L.CATALOG_LOCKED_TIP
    and L.CATALOG_LOCKED ~= L.CATALOG_UNLOCKED, lang .. ": its tooltip: " .. tostring(GameTooltip._lines[1]))
  lock._scripts.OnLeave(lock)
end
ns:SetLanguage("enUS")

out("== locked: the panel moves and sizes the whole window")
do
  local s = panel:GetScale()
  catalog._scripts.OnDragStart(catalog)
  check(panel._moving == true and not catalog._moving, "dragging the panel drags the window")
  panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 250, 950)
  catalog._scripts.OnDragStop(catalog)
  check(panel._moving == false and near(sv.window.left, 250 * s, .5) and near(sv.window.top, 950 * s, .5) and attached(),
    "let go: the window's place saved, the panel still beside it")
end
local function holdGrip(grip, dx, dy, keep, button) -- dx, dy in UIParent units; the right button scales
  M.CursorOn(grip)
  M.mouseDown = true
  grip._scripts.OnMouseDown(grip, button or "RightButton")
  M.cursorX, M.cursorY = M.cursorX + dx * ui, M.cursorY + dy * ui
  M.Frame(0.016)
  if not keep then M.mouseDown = false; M.Frame(0.016) end
end
local function corner(f) -- top left corner, in UIParent units
  local l, _, _, t = U(f)
  return l, t
end
do
  local s0 = panel:GetScale()
  local wl, wt = corner(panel)
  local _, cb0, cr0 = U(catalog)
  local W, H = PANEL_W + SIDE_W, PANEL_H
  holdGrip(cgrip, W * s0 * .2, -H * s0 * .2, true)
  local s1 = panel:GetScale()
  local wl1, wt1 = corner(panel)
  local _, cb1, cr1 = U(catalog)
  check(near(s1, s0 * 1.2, .002), ("the panel's corner held and pulled: the window 20 %% bigger (%.3f -> %.3f)"):format(s0, s1))
  check(near(wl1, wl, .5) and near(wt1, wt, .5), "the window's top left corner in place")
  check(attached(), "the panel still beside it, at the window's scale")
  check(near(cr1 - cr0, W * s0 * .2, .5) and near(cb1 - cb0, -H * s0 * .2, .5), "the corner held follows the cursor")
  M.mouseDown = false; M.Frame(0.016)
  check(near(sv.window.scale, s1, .001) and near(sv.window.left, wl, .5), "let go: the window's scale saved")
end

out("== unlocked: the panel on its own")
do
  local before = { U(catalog) }
  local ps = panel:GetScale()
  lock._scripts.OnEnter(lock) -- the tooltip shown while clicking
  lock:Click()
  local c = sv.catalog
  local after = { U(catalog) }
  check(c.locked == false, "a click on the lock: unlocked")
  check(near(c.left, before[1], .5) and near(c.top, before[4], .5) and near(c.scale, ps, .001),
    ("its place saved: %.1f, %.1f at %.3f"):format(c.left or -1, c.top or -1, c.scale or -1))
  check(sameRect(before, after), "it stays where it was (" .. fmt(before) .. " / " .. fmt(after) .. ")")
  local _, rel = catalog:GetPoint(1)
  check(rel == UIParent and near(catalog:GetScale() * ps, c.scale, .001), "now held to the screen, not to the window")
  check(lockArt("Unlocked"), "open padlock (" .. tostring(lock._normalTex) .. ")")
  check(GameTooltip:IsOwned(lock) and GameTooltip._lines[1] == L.CATALOG_UNLOCKED and GameTooltip._lines[2] == L.CATALOG_UNLOCKED_TIP,
    "the tooltip follows: " .. tostring(GameTooltip._lines[1]))
  lock._scripts.OnLeave(lock)
  for _, lang in ipairs(LANGS) do
    ns:SetLanguage(lang)
    lock._scripts.OnEnter(lock)
    local want = ({ enUS = "Panel detached", frFR = "Panneau détaché", deDE = "Vom Fenster gelöst" })[lang]
    check(GameTooltip._lines[1] == L.CATALOG_UNLOCKED and L.CATALOG_UNLOCKED == want and GameTooltip._lines[2] == L.CATALOG_UNLOCKED_TIP
      and L.CATALOG_UNLOCKED_TIP ~= L.CATALOG_LOCKED_TIP, lang .. ": unlocked, its tooltip: " .. tostring(GameTooltip._lines[1]))
    lock._scripts.OnLeave(lock)
  end
  ns:SetLanguage("enUS")
end
do
  local c = sv.catalog
  local cat0 = { U(catalog) }
  local s0 = panel:GetScale()
  local wl, wt = corner(panel)
  holdGrip(wgrip, -PANEL_W * s0 * .25, PANEL_H * s0 * .25)
  local s1 = panel:GetScale()
  local wl1, wt1 = corner(panel)
  check(near(s1, s0 * .75, .002) and near(wl1, wl, .5) and near(wt1, wt, .5),
    ("the window's corner: the window alone 25 %% smaller (%.3f -> %.3f), its top left in place"):format(s0, s1))
  check(sameRect(cat0, { U(catalog) }) and near(c.scale, s0, .001) and near(catalog:GetScale() * s1, c.scale, .001),
    "the panel keeps its place and size")
  check(near(sv.window.scale, s1, .001), "the window's scale saved")
end
do
  local c = sv.catalog
  local s0, ws = c.scale, panel:GetScale()
  local win0 = { U(panel) }
  local cl, ct = corner(catalog)
  holdGrip(cgrip, 100000, -100000, true)
  check(near(c.scale, ns.MAX_WINDOW_SCALE), "the panel's corner pulled far: at most " .. ns.MAX_WINDOW_SCALE * 100 .. " % (" .. tostring(c.scale) .. ")")
  M.mouseDown = false; M.Frame(0.016)
  holdGrip(cgrip, -100000, 100000)
  check(near(c.scale, ns.MIN_WINDOW_SCALE), "pushed far: at least " .. ns.MIN_WINDOW_SCALE * 100 .. " %")
  -- back to its first size, then 20 % smaller
  local s = c.scale
  holdGrip(cgrip, SIDE_W * (s0 - s), -PANEL_H * (s0 - s))
  check(near(c.scale, s0, .002), "back to its size")
  holdGrip(cgrip, -SIDE_W * s0 * .2, PANEL_H * s0 * .2)
  local cl1, ct1 = corner(catalog)
  local l, b, r, t = U(catalog)
  check(near(c.scale, s0 * .8, .002) and near(r - l, SIDE_W * s0 * .8, .5),
    ("its own corner: the panel alone 20 %% smaller (%.3f -> %.3f)"):format(s0, c.scale))
  check(near(cl1, cl, .5) and near(ct1, ct, .5), "its top left corner in place")
  check(near(panel:GetScale(), ws) and sameRect(win0, { U(panel) }), "the window unchanged")
  check(near(sv.catalog.scale, c.scale) and sv.catalog == c, "saved (sv.catalog.scale)")
end
local NL, NT -- where the panel is put
do
  local c = sv.catalog
  local win0 = { U(panel) }
  catalog._scripts.OnDragStart(catalog)
  check(catalog._moving == true and not panel._moving, "dragging the panel moves the panel alone")
  NL, NT = 1400, 1000
  catalog:ClearAllPoints(); catalog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", NL / c.scale, NT / c.scale) -- where the game leaves it
  catalog._scripts.OnDragStop(catalog)
  local l, t = corner(catalog)
  check(not catalog._moving and near(c.left, NL, .5) and near(c.top, NT, .5) and near(l, NL, .5) and near(t, NT, .5),
    ("let go: its new place saved (%.1f, %.1f)"):format(c.left or -1, c.top or -1))
  check(sameRect(win0, { U(panel) }), "the window did not move")
  panel._scripts.OnDragStart(panel)
  panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 200 / panel:GetScale(), 980 / panel:GetScale())
  panel._scripts.OnDragStop(panel)
  l, t = corner(catalog)
  check(near(sv.window.left, 200, .5) and near(l, NL, .5) and near(t, NT, .5), "the window dragged: the panel stays where it is")
end

out("== on its own, at its own scale: spells still dragged onto the window's rows")
do
  check(not near(catalog:GetEffectiveScale(), panel:GetEffectiveScale(), .01), ("the panel at %.0f %%, the window at %.0f %%")
    :format(sv.catalog.scale * 100, panel:GetScale() * 100))
  local group, row, line
  for _, g in ipairs(catalog.groups) do if g.class == "DRUID" then group = g end end
  for _, r in ipairs(group and group.rows or {}) do if r:IsVisible() then row = r; break end end
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text == ns:RowName("above", 1) and r:IsVisible() and descends(r, pages[3]) and r._parent._kind == "Button" then line = r._parent end
  end
  check(row and line, "a druid spell in the panel (" .. tostring(row ~= nil) .. "), the window's Top 1 row (" .. tostring(line ~= nil) .. ")")
  if row and line then
    local before = #ns.db.rows.above[1]
    M.mouseDown = true
    row._scripts.OnDragStart(row)
    M.CursorOn(line); M.Frame(0.016)
    M.mouseDown = false; row._scripts.OnDragStop(row)
    check(#ns.db.rows.above[1] == before + 1, "dragged from the panel onto Top 1: added (" .. before .. " -> " .. #ns.db.rows.above[1] .. ")")
    local function lastIcon()
      local icon
      for _, f in ipairs(M.frames) do if f:GetParent() == line and f.landing and f.entry ~= nil and f:IsVisible() then icon = f end end
      return icon
    end
    local icon = lastIcon()
    local n = #ns.db.rows.above[1]
    M.mouseDown = true
    icon._scripts.OnDragStart(icon)
    M.CursorOn(catalog); M.Frame(0.016)
    M.mouseDown = false; icon._scripts.OnDragStop(icon)
    check(#ns.db.rows.above[1] == n, "an icon of the row let go over the panel, away from the window: kept")
    icon = lastIcon()
    M.mouseDown = true
    icon._scripts.OnDragStart(icon)
    M.cursorX, M.cursorY = 2, 2; M.Frame(0.016) -- bottom left of the screen, on neither
    M.mouseDown = false; icon._scripts.OnDragStop(icon)
    check(#ns.db.rows.above[1] == n - 1, "let go on neither: removed")
  end
end
local catRect = { U(catalog) }
local winScale = panel:GetScale()
panel:Hide()
open()
goPage(3)
check(catalog:IsShown() and sameRect(catRect, { U(catalog) }) and lockArt("Unlocked"), "the window closed and opened again: the panel where it was, at its size, unlocked")
ns:SetWindowScale(1.1)
check(sameRect(catRect, { U(catalog) }), "the window's scale set on the General page: the panel unchanged")
ns:SetWindowScale(winScale)

out("== a /reload")
reload()
open()
goPage(3)
check(sv.catalog.locked == false and near(sv.catalog.left, NL, .5) and near(sv.catalog.top, NT, .5), "saved: unlocked, its place")
check(catalog:IsShown() and sameRect(catRect, { U(catalog) }) and lockArt("Unlocked"),
  "the panel where it was, at its size (" .. fmt(catRect) .. " / " .. fmt({ U(catalog) }) .. ")")
check(near(panel:GetScale(), winScale) and near(sv.window.left, 200, .5), "the window too")
check(sv.portraits.DRUID == 3 and sv.portraits.WARRIOR == 2 and portrait._file == ICON_DIR .. ns.SPECS.DRUID[3], "the specialisation icons kept")

out("== unlocked: the panel is not pushed back into the screen")
do
  local sw = UIParent:GetWidth()
  local s = panel:GetScale()
  -- the window close to the right edge: no room for the panel beside it
  local left = sw - PANEL_W * s - 40
  panel._scripts.OnDragStart(panel)
  panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / s, 980 / s)
  panel._scripts.OnDragStop(panel)
  goPage(1)
  goPage(3)
  check(near(sv.window.left, left, .5) and sameRect(catRect, { U(catalog) }), "the panel shown again: the window not moved (FitSidePanel only when locked)")
end

out("== locked again: back beside the window")
do
  lock:Click()
  local c = sv.catalog
  check(c.locked == true and c.left == nil and c.top == nil and c.scale == nil, "the lock clicked: locked, the place forgotten")
  check(attached() and lockArt("Locked"), "beside the window again, at its scale; closed padlock")
  local _, _, r = U(catalog)
  check(r <= UIParent:GetWidth() + 0.5 and sv.window.left < UIParent:GetWidth() - PANEL_W * panel:GetScale() - 40,
    ("the window moved left so the panel fits on the screen (panel's right %.0f, screen %.0f)"):format(r, UIParent:GetWidth()))
end

out("== /cl reset pos")
do
  lock:Click() -- unlocked
  local c = sv.catalog
  catalog._scripts.OnDragStart(catalog)
  catalog:ClearAllPoints(); catalog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 30 / c.scale, 400 / c.scale)
  catalog._scripts.OnDragStop(catalog)
  check(near(c.left, 30, .5), "the panel put somewhere else")
  SlashCmdList.CLARACOMBOPOINTS("reset pos")
  -- unlocked, it comes back beside the centred window and stays on its own from there
  local function beside()
    M.ResetLayout()
    local pl, pb, pw, ph = M.AbsRect(panel)
    local cl, cb, cw, ch = M.AbsRect(catalog)
    return near(cl, pl + pw, 1) and near(cb + ch, pb + ph, 1) and near(ch, ph, 1)
  end
  check(sv.window.left == nil and c.locked == false and c.left ~= nil and not near(c.left, 30, .5),
    "/cl reset pos: the window's place forgotten; the panel still detached, with a new place")
  check(beside() and not attached(), "the panel beside the window again, at its scale, on its own")
  -- a screen of 1365 x 768 UI units (1920 x 1080 at UI scale 1): the window in the middle leaves
  -- no room on the right for the panel
  local physH = S.physH
  S.physH = 2028
  local sw = UIParent:GetWidth()
  lock:Click() -- locked
  SlashCmdList.CLARACOMBOPOINTS("reset pos")
  local _, _, r = U(catalog)
  check(r <= sw + 0.5, ("locked, a narrow screen (%.0f): after /cl reset pos the panel on the screen (its right at %.0f)"):format(sw, r))
  lock:Click() -- unlocked
  SlashCmdList.CLARACOMBOPOINTS("reset pos")
  _, _, r = U(catalog)
  check(beside() and r <= sw + 0.5,
    ("unlocked, the same screen: after /cl reset pos the panel beside the window, on the screen (its right at %.0f)"):format(r))
  S.physH = physH
  SlashCmdList.CLARACOMBOPOINTS("reset pos")
end

out("== ns:ResetAddon(): locked again, the icons back")
do
  if sv.catalog.locked then lock:Click() end
  local c = sv.catalog
  catalog._scripts.OnDragStart(catalog)
  catalog:ClearAllPoints(); catalog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 30 / (c.scale or 1), 400 / (c.scale or 1))
  catalog._scripts.OnDragStop(catalog)
  check(c.locked == false and c.left ~= nil and lockArt("Unlocked"), "unlocked, put somewhere")
  ns:ResetAddon()
  check(sv.catalog.locked == true and sv.catalog.left == nil and sv.catalog.scale == nil, "reset: sv.catalog = { locked = true }")
  check(attached() and lockArt("Locked"), "the panel beside the window, closed padlock")
  check(next(sv.portraits) == nil, "the specialisation icons forgotten")
  tab("DRUID")
  check(portrait._file == ICON_DIR .. "Ability_Druid_CatForm", "the druid tab's portrait: the class's icon again")
  -- with the window closed
  lock:Click()
  check(sv.catalog.locked == false, "unlocked again")
  panel:Hide()
  ns:ResetAddon()
  open()
  goPage(3)
  check(sv.catalog.locked == true and attached() and lockArt("Locked"), "reset with the window closed: opened, the panel locked beside it")
end

out("== a lock button without its old art: the game's padlock")
do
  local t = lock:GetNormalTexture()
  t.GetTextureFileID = function() return nil end -- the file is not in this client
  lock.SetNormalAtlas = function(self, a) self._normalAtlas = a; self:GetNormalTexture():SetAtlas(a) end
  lock.SetPushedAtlas = function(self, a) self._pushedAtlas = a end
  lock:Click() -- unlocked
  check(lock._normalAtlas == "QuestSharing-Padlock" and lock._pushedAtlas == "QuestSharing-Padlock" and t._desat == true and near(t:GetAlpha(), .6),
    "unlocked: the padlock atlas, grayed")
  lock:Click() -- locked
  check(lock._normalAtlas == "QuestSharing-Padlock" and t._desat == false and near(t:GetAlpha(), 1), "locked: the padlock in colour")
  t.GetTextureFileID, lock.SetNormalAtlas, lock.SetPushedAtlas = nil, nil, nil
end

out("== saved panel values, cleaned at load")
do
  local CASES = {
    { "a place and scale: kept", { locked = false, left = 120, top = 800, scale = 1.25 }, { locked = false, left = 120, top = 800, scale = 1.25 } },
    { "a lock not false: locked", { locked = "no", left = 1, top = 1, scale = 1 }, { locked = true } },
    { "not a table", "junk", { locked = true } },
    { "no lock saved", {}, { locked = true } },
    { "locked with a place: no place", { locked = true, left = 1, top = 1, scale = 1 }, { locked = true } },
    { "a place not a number", { locked = false, left = "x", top = 1, scale = 1 }, { locked = false } },
    { "no scale", { locked = false, left = 1, top = 1 }, { locked = false } },
    { "a scale over 200 %", { locked = false, left = 1, top = 1, scale = 5 }, { locked = false } },
    { "a scale under 40 %", { locked = false, left = 1, top = 1, scale = .1 }, { locked = false } },
    { "NaN", { locked = false, left = 0 / 0, top = 1, scale = 1 }, { locked = false } },
    { "infinite", { locked = false, left = 1, top = 1 / 0, scale = 1 }, { locked = false } },
  }
  for _, case in ipairs(CASES) do
    reload(function(db) db.catalog = deepcopy(case[2]) end)
    local c, want = sv.catalog, case[3]
    local ok = type(c) == "table" and count(c) == count(want)
    for k, v in pairs(want) do if c[k] ~= v then ok = false end end
    local got = {}
    for k, v in pairs(type(c) == "table" and c or {}) do got[#got + 1] = k .. "=" .. tostring(v) end
    table.sort(got)
    check(ok, case[1] .. " (" .. table.concat(got, " ") .. ")")
    if case[1]:find("kept") then
      open()
      goPage(3)
      local l, b, r, t = U(catalog)
      check(near(l, 120, .5) and near(t, 800, .5) and near(r - l, SIDE_W * 1.25, .5) and lockArt("Unlocked"),
        ("opened: the panel at its saved place (%.1f, %.1f), 125 %%"):format(l, t))
      panel:Hide()
    elseif not want.locked and not want.left then
      open()
      goPage(3)
      check(attached() and lockArt("Unlocked"), "  opened: beside the window, unlocked")
      catalog._scripts.OnDragStart(catalog)
      local _, rel = catalog:GetPoint(1)
      check(sv.catalog.left ~= nil and near(sv.catalog.scale, panel:GetScale()) and catalog._moving, "  dragged: from where it is, on its own")
      catalog._scripts.OnDragStop(catalog)
      panel:Hide()
    end
  end
end

out("== the battleground rule in profiles saved by an older version")
reload(function(db)
  db.profiles.DRUID.hideWhen = { solo = false, party = false, raid = false, dungeon = true, raid10 = false, raid20 = false, raid40 = false }
  db.profiles.ROGUE.hideWhen.battleground = "yes"
end)
check(sv.profiles.DRUID.hideWhen.battleground == false and sv.profiles.DRUID.hideWhen.dungeon == true,
  "no battleground saved: off (the other rules kept)")
check(sv.profiles.ROGUE.hideWhen.battleground == false, "a value not true/false: off")

---------------------------------------------------------------------------
out("== the look of the groups: the character sheet's bronze border")
reload(function(db) db.catalog = nil end)
open()
local function sections()
  local list = {}
  for _, f in ipairs(M.frames) do
    if f.title and f.Fit and descends(f, panel) then
      for _, pg in ipairs(pages) do if f._parent == pg.back or descends(f, pg.back) then list[#list + 1] = f; break end end
    end
  end
  return list
end
do
  local list = sections()
  local bordered, filled, plain = 0, 0, 0
  local bad = {}
  for _, f in ipairs(list) do
    local b = f.border
    local okBorder = b and b._atlas == "common-insideframe" and b._layer == "BORDER" and b._parent == f
    if okBorder then
      local p1, p2 = b._points[1], b._points[2]
      okBorder = p1 and p2 and p1[1] == "TOPLEFT" and p1[4] == 1 and p1[5] == 1 and p2[1] == "BOTTOMRIGHT" and p2[4] == -4 and p2[5] == 2
    end
    if okBorder then bordered = bordered + 1 else bad[#bad + 1] = strip(f.title._text) end
    for _, r in ipairs(M.regions) do
      if r._parent == f and r._kind == "Texture" and r._layer == "BACKGROUND" and r._color and r._color[1] == 0 and r._color[2] == 0
        and r._color[3] == 0 and near(r._color[4], .55) then filled = filled + 1; break end
    end
    if f._backdrop then plain = plain + 1 end
  end
  check(#list >= 14, #list .. " groups on the five pages")
  check(bordered == #list, "each with the atlas common-insideframe, on the BORDER layer, placed as the character sheet's ("
    .. bordered .. (#bad > 0 and ("; not: " .. table.concat(bad, ", ")) or "") .. ")")
  check(filled == #list and plain == 0, "over a dark fill, no tooltip backdrop (" .. filled .. " filled, " .. plain .. " backdrops)")
  check(menu.border and menu.border._atlas == "common-insideframe" and not menu._backdrop, "the specialisations menu too")
  local n = 0
  for _, f in ipairs(list) do if M.IsGroupBox(f) then n = n + 1 end end
  check(n == #list, "all seen as group boxes")
end

out("== without that atlas: the tooltip border in bronze")
do
  local getAtlas = C_Texture.GetAtlasInfo
  reload(function()
    C_Texture.GetAtlasInfo = function(atlas)
      if atlas == "common-insideframe" then return nil end
      return getAtlas(atlas)
    end
  end)
  open()
  local list = sections()
  local ok, bad = 0, {}
  for _, f in ipairs(list) do
    local bd = f._backdrop
    if bd and bd.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border" and bd.bgFile == "Interface\\Tooltips\\UI-Tooltip-Background"
      and f._bdBorder and near(f._bdBorder[1], .72) and near(f._bdBorder[2], .58) and near(f._bdBorder[3], .34)
      and f._bdColor and f._bdColor[1] == 0 and near(f._bdColor[4], .55) and f.border == nil then
      ok = ok + 1
    else
      bad[#bad + 1] = strip(f.title._text)
    end
  end
  check(#list >= 14 and ok == #list, ok .. " / " .. #list .. " groups with the tooltip border in bronze, over a dark fill"
    .. (#bad > 0 and (" (not: " .. table.concat(bad, ", ") .. ")") or ""))
  check(menu._backdrop and menu._backdrop.edgeFile:find("Tooltip") and menu.border == nil, "the specialisations menu too")
  check(menuFillAlpha() >= .9, ("its background hides what is under it: opacity %.0f %%"):format(menuFillAlpha() * 100))
  rightClick()
  check(menu:IsShown() and #shownRows() == 4, "and it still opens")
  menu:Hide()
  local n = 0
  for _, f in ipairs(list) do if M.IsGroupBox(f) then n = n + 1 end end
  check(n == #list, "all seen as group boxes")
  C_Texture.GetAtlasInfo = getAtlas
  panel:Hide()
end

out(("\n%d failure(s)"):format(fails))
return fails
