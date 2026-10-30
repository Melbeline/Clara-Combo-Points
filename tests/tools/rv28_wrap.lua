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
sv.window.w, sv.window.h = 640, 1000
ns:SetWindowScale(1)
goPage(3)
ns.db.rows.above[3] = {}
for i = 1, 15 do ns.db.rows.above[3][i] = 1243 + (i > 1 and 100000 + i or 0) end
panel:Refresh()
local byIndex = {}
for _, f in ipairs(M.frames) do
  if f.landing and f.entry ~= nil and f:IsVisible() and f.index and f:GetParent().Wrap then
    local l, b, r, t = U(f)
    if l then byIndex[f.index] = { f = f, l = l, b = b, r = r, t = t, line = f:GetParent() } end
  end
end
local function drag(fromI, toX, toY)
  local src = byIndex[fromI].f
  M.CursorOn(src); M.mouseDown = true
  src._scripts.OnDragStart(src); M.Frame(0.016)
  M.cursorX, M.cursorY = toX * ui, toY * ui
  M.Frame(0.016)
  M.mouseDown = false; src._scripts.OnDragStop(src); M.Frame(0.016)
end
local id15 = ns.db.rows.above[3][15]
-- icon 15 (second line) dropped on the slot of icon 3 (first line)
local s3 = byIndex[3]
drag(15, (s3.l + s3.r) / 2, (s3.b + s3.t) / 2)
local at
for i, v in ipairs(ns.db.rows.above[3]) do if v == id15 then at = i end end
out("icon 15 dropped on slot 3: now at " .. tostring(at))
-- the 3rd icon dropped on the second line's 2nd slot (index 12)
panel:Refresh()
byIndex = {}
for _, f in ipairs(M.frames) do
  if f.landing and f.entry ~= nil and f:IsVisible() and f.index and f:GetParent().Wrap then
    local l, b, r, t = U(f)
    if l then byIndex[f.index] = { f = f, l = l, b = b, r = r, t = t } end
  end
end
local id = ns.db.rows.above[3][3]
local s12 = byIndex[12]
drag(3, (s12.l + s12.r) / 2, (s12.b + s12.t) / 2)
for i, v in ipairs(ns.db.rows.above[3]) do if v == id then at = i end end
out("icon 3 dropped on slot 12: now at " .. tostring(at))
