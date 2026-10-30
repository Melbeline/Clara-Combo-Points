-- rogue: the Layout page's sliders follow the bar named above them; Rectangular icons stay on
-- the combo cells at any combo bar scale
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"; S.powerType = 3
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100

out("== Bars page: a bar the class shown has not")
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
for _, f in ipairs(M.frames) do if f.class == "DRUID" and f.Click then f:Click() end end
for _, f in ipairs(M.frames) do if f.page == 2 and f.Click then f:Click() end end -- the Bars page, in the list on the left
local manaRow
for _, f in ipairs(M.frames) do if f.key == "mana" and f.show and f:IsVisible() then manaRow = f end end
check(manaRow ~= nil, "the druid's bar list has a mana row")
local barsPage = manaRow and manaRow:GetParent():GetParent()
-- the picked bar's section title (on the right column, at the top of the page)
local function PickedTitle()
  local title, manaShown
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r:IsShown() and r._parent:IsVisible() then
      local pt = r._points and r._points[1]
      if (r._parent == barsPage or r._parent == barsPage.colR) and pt and pt[1] == "TOPLEFT" and pt[4] == 380 and pt[5] == -56 then title = r._text end
      if r._text == "Mana" then manaShown = true end
    end
  end
  return title, manaShown
end
if manaRow then manaRow:Click() end
check(PickedTitle() == "Mana", "a click on the druid's mana row picks it (" .. tostring(PickedTitle()) .. ")")
panel:Hide()
SlashCmdList.CLARACOMBOPOINTS("") -- back on the Rogue tab, in one refresh
local sliders = {}
for _, f in ipairs(M.frames) do if f._kind == "Slider" and f:IsVisible() and f:GetParent() ~= panel then sliders[#sliders + 1] = f end end
local title, manaShown = PickedTitle()
check(title == "Energy" and not manaShown, "the energy bar is picked (" .. tostring(title) .. (manaShown and ", Mana still shown" or "") .. ")")
check(sliders[2] and (sliders[2]:GetParent() == barsPage or sliders[2]:GetParent() == barsPage.colR) and sliders[2]:GetValue() == ns.db.bars.power.height, "the height slider shows its height (" .. tostring(sliders[2] and sliders[2]:GetValue()) .. ")")
local before = ns.db.bars.power.height
sliders[2]:SetValue(sliders[2]:GetValue() + 1)
check(ns.db.bars.power.height == before + 1, "one step up: one more")
panel:Hide()

out("== Rectangular icons on a scaled combo bar")
ns.db.icons.shape = "CELL"
ns.db.rows.above[1] = { 6774, 1943, 774, 8921, 139 }
for _, scale in ipairs({ 2, 0.5, 1.37 }) do
  ns.db.bars.combo.scale = scale
  ns:ApplyLayout()
  local cells = {}
  for _, f in ipairs(M.frames) do if f._parent == ns.comboRow and f._kind == "StatusBar" then cells[#cells + 1] = f end end
  local slots
  for _, f in ipairs(M.frames) do if f.slots and f.side == "above" and f.k == 1 then slots = f.slots end end
  local worst = 0
  for i = 1, 5 do
    M.ResetLayout()
    local cl, _, cw = M.AbsRect(cells[i]); M.ResetLayout()
    local sl, _, sw = M.AbsRect(slots[i])
    worst = math.max(worst, math.abs(sl - cl), math.abs(sw - cw))
  end
  check(worst < 0.01, ("scale %d%%: each icon over its cell (off by %.2f)"):format(scale * 100, worst))
end

out(("\n%d failure(s)"):format(fails))
return fails
