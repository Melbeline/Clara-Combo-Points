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
local fs = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
for _, lang in ipairs({ "enUS", "frFR", "deDE" }) do
  ns:SetLanguage(lang)
  for _, w in ipairs({ 102, 62 }) do
    local over, total, ex = 0, 0, {}
    for _, g in ipairs(catalog.groups) do
      for _, rec in ipairs(g.recs) do
        if #rec.ranks > 1 then
          total = total + 1
          fs:SetWidth(w); fs:SetText(ns:CatalogName(rec))
          local lines = fs:GetStringHeight() / 10
          -- a single word wider than the column is cut too
          local wide = false
          for word in ns:CatalogName(rec):gmatch("%S+") do fs:SetText(word); if fs:GetStringWidth() > w then wide = true end end
          if lines > 2 or wide then over = over + 1; if #ex < 4 then ex[#ex + 1] = ns:CatalogName(rec) end end
        end
      end
    end
    out(("%s name column %d px: %d of %d multi-rank names cut (%s)"):format(lang, w, over, total, table.concat(ex, " | ")))
  end
end
