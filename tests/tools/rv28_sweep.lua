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
local function goClass(c)
  for _, f in ipairs(M.frames) do
    if f.class == c and f._scripts and f._scripts.OnClick and f.SetActive then f._scripts.OnClick(f) return end
  end
end
local function visualUnder(page)
  local list = {}
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r:IsVisible() and r._text and r._text ~= "" and (under(r, page) or under(r, page.back)) then list[#list + 1] = r end
  end
  for _, f in ipairs(M.frames) do
    if (f._kind == "Button" or f._kind == "Slider" or f._kind == "EditBox" or f._kind == "CheckButton") and f:IsVisible() and under(f, page) then list[#list + 1] = f end
  end
  return list
end
local problems = 0
for _, lang in ipairs({ "enUS", "frFR", "deDE" }) do
  ns:SetLanguage(lang)
  for _, class in ipairs({ "PRIEST", "DRUID", "WARRIOR", "ROGUE" }) do
    goClass(class)
    for _, W in ipairs({ 640, 700, 760, 904, 910, 1300 }) do
      for _, H in ipairs({ 540, 720 }) do
        sv.window.w, sv.window.h = W, H
        ns:SetWindowScale(1)
        for pg = 1, 5 do
          goPage(pg)
          panel:Refresh()
          local page = pages[pg]
          local boxes = boxesOf(page)
          local tag = ("%s %s %dx%d page %d"):format(lang, class, W, H, pg)
          if overlap(boxes) then out(tag .. ": boxes overlap"); problems = problems + 1 end
          local vl, vb, vr, vt = U(body)
          local sl, sb, sr, st = U(sheet)
          for _, b in ipairs(boxes) do
            local l, bb, r, t = U(b)
            if r > vr + .5 then out(tag .. (": box right %.0f > view %.0f"):format(r, vr)); problems = problems + 1 end
            if bb < sb - .5 then out(tag .. (": box bottom %.0f below the sheet's %.0f"):format(bb, sb)); problems = problems + 1 end
          end
          for _, r in ipairs(visualUnder(page)) do
            local l, bb, rr, t = U(r)
            local name = r._text or (r.text and r.text._text) or (r.Text and r.Text._text) or r._kind
            if rr > vr + 1 and l < vr then out(tag .. (": '%s' cut at the view's right (%.0f > %.0f)"):format(tostring(name), rr, vr)); problems = problems + 1
            elseif l >= vr then out(tag .. (": '%s' right of the view entirely (%.0f)"):format(tostring(name), l)); problems = problems + 1 end
            if bb < sb - 1 then out(tag .. (": '%s' below the scroll range (%.0f < %.0f)"):format(tostring(name), bb, sb)); problems = problems + 1 end
            if t > st + 1 and t - (st) > 50 then out(tag .. (": '%s' above the sheet (%.0f > %.0f)"):format(tostring(name), t, st)); problems = problems + 1 end
          end
        end
      end
    end
  end
end
out("problems: " .. problems)
