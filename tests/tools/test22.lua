-- the druid's bars with energy or rage off, and the boxes of the bars list and colour rows (druid, warrior's rage bar off)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b, e) return a and b and math.abs(a - b) < (e or 0.01) end

local ns = {}
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3 -- Cat Form
S.mana, S.manaMax = 1200, 3000
S.target = { cp = 2, hostile = true }; S.energy = 60; S.rage = 30
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
M.Frame(0.016)
local db = ns.db
local function rect(f) M.ResetLayout(); local l, b, w, h = M.AbsRect(f); local s = ns.hud:GetEffectiveScale(); return l / s, b / s, w / s, h / s end
local function top(f) local _, b, _, h = rect(f); return b + h end
local function bottom(f) local _, b = rect(f); return b end
local function shift(pt) S.powerType = pt; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016) end

out("== druid: energy bar off, rage bar on")
ns:SetElementOn("energy", false)
check(not ns.powerBar:IsShown() and ns.manaBar:IsShown(), "Cat Form: no energy bar")
check(near(top(ns.manaBar), bottom(ns.comboRow) - ns.ROW_GAP), "the mana bar right under the combo points")
local catMana = top(ns.manaBar)
shift(1) -- Bear Form
check(ns.powerBar:IsShown(), "Bear Form: the rage bar")
check(near(top(ns.powerBar), bottom(ns.comboRow) - ns.ROW_GAP) and near(top(ns.manaBar), bottom(ns.powerBar) - ns.ROW_GAP), "between the combo points and the mana")
shift(0) -- caster form
check(not ns.powerBar:IsShown() and not ns.comboRow:IsShown() and ns.manaBar:IsShown(), "caster form: mana alone")
check(near(top(ns.manaBar), catMana), "where it is in Cat Form")
shift(3)
ns:SetElementOn("energy", true)
ns:SetElementOn("rage", false)
shift(1)
check(not ns.powerBar:IsShown() and near(top(ns.manaBar), bottom(ns.comboRow) - ns.ROW_GAP), "rage off: Bear Form without the rage bar, no hole")
shift(3)
check(ns.powerBar:IsShown(), "Cat Form: the energy bar")
ns:SetElementOn("rage", true)

out("== caster form to Bear Form, every combo cell and the rage bar off")
for i = 1, 5 do db.disabled["cp" .. i] = true end
ns:SetElementOn("rage", false)
shift(0)
shift(1)
check(not ns.powerBar:IsShown() and near(top(ns.manaBar), top(ns.hud)), "the mana bar at the top: no room left for the rage bar (" .. (top(ns.hud) - top(ns.manaBar)) .. ")")
shift(3)
check(ns.powerBar:IsShown() and near(top(ns.powerBar), top(ns.hud)), "Cat Form: the energy bar on top")
shift(1)
check(near(top(ns.manaBar), top(ns.hud)), "and Bear Form again: same as from caster form")
for i = 1, 5 do db.disabled["cp" .. i] = false end
ns:SetElementOn("rage", true)

out("== Bear Form: points only on cells turned off")
db.disabled.cp1, db.disabled.cp2 = true, true; ns:ApplyAll()
S.target = { cp = 2, hostile = true }; M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
check(ns.iconsOnBar == true, "two points, cells 1 and 2 off: nothing lit, the icons come down onto the rage bar")
S.target = { cp = 3, hostile = true }; M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
check(ns.iconsOnBar == false, "a third point lights cell 3: they go back up")
db.disabled.cp1, db.disabled.cp2 = false, false; ns:ApplyAll()
shift(3)

out("== druid: the bars list and the colour rows")
SlashCmdList.CLARACOMBOPOINTS("")
-- the list of pages on the left: one button per page (1 General, 2 Bars...)
local function goPage(n) for _, f in ipairs(M.frames) do if f.page == n and f._kind == "Button" and f.name and f.desc then f:Click() end end end
-- Bars page: a row per bar of the class (grip, box, name, swatches); a click picks it
local function barRow(key)
  for _, f in ipairs(M.frames) do if f.swatches and f.show and f.key == key and f:IsVisible() then return f end end
end
local function pick(key) local r = barRow(key); if r then r:Click() end; return r end
-- a colour row (box, label, swatch, opacity), shown: its holder, its box if shown
local function colorRow(label)
  for _, f in ipairs(M.frames) do
    if f.on and f.swatch and f.slider and f.label and f.label._text == label and f:IsVisible() then
      return f, (f.on:IsVisible() and f.on.check or nil)
    end
  end
end
local function checkLabelled(label)
  for _, f in ipairs(M.frames) do
    if f._kind == "CheckButton" and f:IsVisible() and f.Text and f.Text._text == label then return f end
  end
end
-- every part has one switch: the list's box for each bar, a box for each part of a bar of
-- several, the rage about to be spent, the background; the value has its own check
local count = 0
local function boxed(label)
  local row, box = colorRow(label)
  if box then count = count + 1 else out("    no box for " .. label) end
  return box
end
local function unboxed(label)
  local row, box = colorRow(label)
  if not row then out("    no row for " .. label) end
  return row ~= nil and box == nil
end
goPage(2)
local listOk = true
for _, key in ipairs({ "combo", "power", "mana", "health" }) do
  local r = barRow(key)
  if r and r.show:IsVisible() then count = count + 1 else listOk = false; out("    no box for the bar " .. key) end
end
check(listOk, "the druid's four bars in the list, each with its box")
pick("combo")
for i = 1, 5 do boxed("Combo point " .. i) end
pick("power")
local energyBox, rageBox, costBox = boxed("Energy bar"), boxed("Rage bar"), boxed("Rage about to be spent")
pick("mana")
local manaOk = unboxed("Mana bar")
pick("health")
local healthOk = unboxed("Health bar") and checkLabelled("Health in the class color") ~= nil
goPage(1)
boxed("Bar background (empty part)")
local textOk = unboxed("Color") and checkLabelled("Show energy / rage value") ~= nil
check(count == 13 and manaOk and healthOk and textOk,
  "4 bars + 5 cells + energy, rage, rage to spend + background: thirteen boxes (" .. count .. "); mana, health, text colour switched elsewhere")

out("== druid: the energy and rage boxes of the power bar")
goPage(2); pick("power")
energyBox = select(2, colorRow("Energy bar"))
energyBox:Click()
check(db.disabled.energy == true and not ns.powerBar:IsShown(), "energy box unticked: Cat Form without the energy bar")
check(barRow("power").show.check:GetChecked() == true, "the list keeps the power bar on (rage still on)")
rageBox = select(2, colorRow("Rage bar"))
rageBox:Click()
check(db.disabled.rage == true and barRow("power").show.check:GetChecked() == false, "rage off too: the list shows the bar off")
barRow("power").show.check:Click()
check(db.disabled.energy == false and db.disabled.rage == false and ns.powerBar:IsShown(), "the list's box turns both back on")
local predict = db.predict
costBox = select(2, colorRow("Rage about to be spent"))
costBox:Click()
check(db.predict == not predict and costBox:GetChecked() == db.predict, "the rage-to-spend row's box is the prediction switch")
costBox:Click()
check(db.predict == predict, "back as it was")

out("== warrior tab: the rage bar off")
for _, f in ipairs(M.frames) do if f.class == "WARRIOR" and f._kind == "Button" then f:Click() end end
check(ns.profileClass == "WARRIOR" and barRow("power") and not barRow("combo") and not barRow("mana"), "the warrior's list: no combo points, no mana")
pick("power")
local rageRow, rageRowBox = colorRow("Rage bar")
local _, wCostBox = colorRow("Rage about to be spent")
check(rageRow and not rageRowBox and wCostBox and not colorRow("Energy bar"), "rage picked: its row without a box (one part), the rage to spend with its box")
barRow("power").show.check:Click()
check(ns.db.disabled.rage == true and not ns:BarOn("power"), "the list's box: the warrior's rage bar off")
barRow("power").show.check:Click()
check(ns.db.disabled.rage == false, "back on")
for _, f in ipairs(M.frames) do if f.class == "DRUID" and f._kind == "Button" then f:Click() end end
ClaraComboPointsOptions:Hide()

out(("\n%d failure(s)"):format(fails))
return fails
