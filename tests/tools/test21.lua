-- the boxes of the bars list and of the colour rows: each part turned off is not drawn and takes no room
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b, e) return a and b and math.abs(a - b) < (e or 0.01) end

ClaraComboPointsDB = { profiles = { DRUID = { disabled = { cp2 = "x", energy = true, junk = true } } } }
local ns = {}
S.class = "ROGUE"; S.locale = "frFR"; S.powerType = 3
S.target = { cp = 3, hostile = true }; S.energy = 60
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
M.Frame(0.016)
local db = ns.db
local sv = ns.sv

out("== saved variables")
local dd = sv.profiles.DRUID.disabled
check(dd.cp2 == false and dd.energy == true and dd.junk == nil and dd.bg == false, "wrong kinds back to on, unknown keys gone, good ones kept")

local cells = {}
for _, f in ipairs(M.frames) do if f._parent == ns.comboRow and f._kind == "StatusBar" then cells[#cells + 1] = f end end
local function rect(f) M.ResetLayout(); local l, b, w, h = M.AbsRect(f); local s = ns.hud:GetEffectiveScale(); return l / s, b / s, w / s, h / s end
local function top(f) local _, b, _, h = rect(f); return b + h end

out("== the bars list and the colour rows: a box for each part")
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
-- the list of pages on the left: one button per page (1 General, 2 Bars...)
local function goPage(n) for _, f in ipairs(M.frames) do if f.page == n and f._kind == "Button" and f.name and f.desc then f:Click() end end end
-- Bars page: a row per bar of the class (grip, box, name, swatches); a click picks it
local function barRow(key)
  for _, f in ipairs(M.frames) do if f.swatches and f.show and f.key == key and f:IsVisible() then return f end end
end
local function pick(key) local r = barRow(key); if r then r:Click() end; return r end
-- a colour row (box, label, swatch, opacity), shown: its holder, its box if shown, its label
local function colorRow(label)
  for _, f in ipairs(M.frames) do
    if f.on and f.swatch and f.slider and f.label and f.label._text == label and f:IsVisible() then
      return f, (f.on:IsVisible() and f.on.check or nil), f.label
    end
  end
end
local function rowBox(label) local _, box, fs = colorRow(label); return box, fs end
local function checkLabelled(label)
  for _, f in ipairs(M.frames) do
    if f._kind == "CheckButton" and f:IsVisible() and f.Text and f.Text._text == label then return f end
  end
end
goPage(2)
local listOk = true
for _, key in ipairs({ "combo", "power", "health" }) do
  local r = barRow(key)
  if not (r and r.show:IsVisible()) then listOk = false; out("    no box for the bar " .. key) end
end
check(listOk and barRow("mana") == nil, "the rogue's bars (combo, energy, health), each with its box; no mana")
check(barRow("combo").show.check:GetChecked() == true and barRow("power").show.check:GetChecked() == true
  and barRow("health").show.check:GetChecked() == false, "combo and energy on, health off by default")
pick("combo")
local all = true
for i = 1, 5 do
  local text = "Point de combo " .. i
  if not rowBox(text) then all = false; out("    no box for " .. text) end
end
check(all, "combo points picked: every cell's colour row has its box")
pick("power")
local energyRow, energyRowBox = colorRow("Barre d'énergie")
check(energyRow and not energyRowBox and not colorRow("Barre de rage") and not colorRow("Rage à consommer"),
  "energy picked: its colour row, no box (one part: the list's box switches it), no rage rows for a rogue")
pick("health")
local healthRow, healthRowBox = colorRow("Barre de vie")
check(healthRow and not healthRowBox, "health picked: its colour row, no box (the list's box switches it)")
goPage(1)
check(rowBox("Fond des barres (parties vides)") ~= nil, "General page: the bars' background row has its box")
local textRow, textRowBox = colorRow("Couleur")
check(textRow and not textRowBox and checkLabelled("Afficher la valeur d'énergie") ~= nil,
  "General page: the value's colour row has no box, its own Show the value check is there")
goPage(2); pick("combo")
local box3, label3 = rowBox("Point de combo 3")
check(box3 and box3:GetChecked() == true, "on by default")

out("== a combo cell turned off: the others share the row")
local comboTop = top(ns.comboRow)
local powerTop = top(ns.powerBar)
box3:Click()
check(db.disabled.cp3 == true and not cells[3]:IsShown(), "cell 3 off: not drawn")
local tc = label3._tc
check(tc and near(tc[1], .5) and near(tc[2], .5) and barRow("combo").show.check:GetChecked() == true,
  "its label greyed; the list keeps the combo bar on (four cells left)")
local gap = ns.CP_GAP
local x1, _, w1 = rect(cells[1])
local x2 = rect(cells[2]); local x4 = rect(cells[4]); local x5, _, w5 = rect(cells[5])
local cw = (db.bars.combo.width - 3 * gap) / 4
check(near(w1, cw) and near(x2 - x1, cw + gap) and near(x4 - x2, cw + gap) and near(x5 - x4, cw + gap), "four cells, side by side, no hole")
check(near(x5 + w5 - x1, db.bars.combo.width), "they fill the row's width")
check(near(cells[4]._min, 3) and near(cells[4]._max, 4), "cell 4 still lights up at the 4th point")
for i = 1, 5 do if i ~= 3 then ns.db.disabled["cp" .. i] = true end end
ns:SetElementOn("cp3", false)
check(not ns.comboRow:IsShown(), "every cell off: no combo row")
check(barRow("combo").show.check:GetChecked() == false, "and the list shows the combo bar off")
check(near(top(ns.powerBar), top(ns.hud)) and near(ns.hud:GetHeight(), db.bars.power.height), "the energy bar goes up to the top, the HUD shrinks to it (no hole)")
for i = 1, 5 do ns:SetElementOn("cp" .. i, true) end
check(ns.comboRow:IsShown() and near(top(ns.powerBar), powerTop) and cells[3]:IsShown(), "all on again: as before")
check(barRow("combo").show.check:GetChecked() == true and rowBox("Point de combo 3"):GetChecked() == true, "the list and the cell's box ticked again")

out("== the energy bar turned off")
local energyBox = barRow("power").show.check -- the rogue's power bar is its energy alone
energyBox:Click()
check(db.disabled.energy and not ns.powerBar:IsShown(), "energy bar off: not drawn")
check(near(ns.hud:GetHeight(), db.bars.combo.height), "the HUD is just the combo row")
db.bars.health.show = true; ns:ApplyAll()
check(ns.healthBar:IsShown() and near(top(ns.healthBar), top(ns.comboRow) - db.bars.combo.height - ns.ROW_GAP), "the health bar right under the combo row")
energyBox = barRow("power").show.check; energyBox:Click()
check(not db.disabled.energy and ns.powerBar:IsShown(), "back on")
db.bars.health.show = false; ns:ApplyAll()

out("== the background, the value")
goPage(1)
local bgBox = rowBox("Fond des barres (parties vides)")
bgBox:Click()
check(db.disabled.bg and cells[1].bg._color and cells[1].bg._color[4] == 0 and ns.powerBar.bg._color[4] == 0, "background off: nothing drawn behind")
bgBox:Click()
check(cells[1].bg._color[4] > 0, "back on")
local textBox = checkLabelled("Afficher la valeur d'énergie")
textBox:Click()
check(db.showText == false and not ns:ElementOn("text"), "value off: the General page's Show the value setting")
textBox:Click()
check(db.showText == true and textBox:GetChecked() == true, "back on")

out("== the health bar: its box in the list and its colour row are one setting")
goPage(2)
local healthBox = barRow("health").show.check
check(healthBox:GetChecked() == false, "health off by default")
healthBox:Click()
check(db.bars.health.show == true and ns.healthBar:IsShown() and ns:ElementOn("health"), "ticked: the health bar shows")
pick("health")
local _, _, healthLabel = colorRow("Barre de vie")
check(healthLabel and healthLabel._tc and near(healthLabel._tc[1], 1) and near(healthLabel._tc[2], .82),
  "its colour row shows it on (gold label)")
ns:SetElementOn("health", false)
check(db.bars.health.show == false and not ns.healthBar:IsShown(), "turned off as a part: off")
goPage(1); goPage(2)
_, _, healthLabel = colorRow("Barre de vie")
check(barRow("health").show.check:GetChecked() == false and healthLabel and healthLabel._tc and near(healthLabel._tc[1], .5),
  "and unticked in the list, its colour row greyed")

out("== a profile keeps them")
ns:SaveProfile("ROGUE", "Test")
ns:SetElementOn("cp1", false)
check(ns:ProfileModified("ROGUE"), "a part turned off changes the profile")
ns:LoadProfile("ROGUE", "Test")
check(db.disabled.cp1 == false and cells[1]:IsShown(), "loading puts it back")
panel:Hide()

out("== every bar off: the icons still show")
db.rows.above[1] = { 1784 }
for i = 1, 5 do db.disabled["cp" .. i] = true end
ns:SetElementOn("energy", false)
check(not ns.comboRow:IsShown() and not ns.powerBar:IsShown(), "no bar at all")
check(ns.hud:IsShown() and ns.iconLayer:IsVisible(), "the HUD still shows, for its icons")
local row
for _, f in ipairs(M.frames) do if f.slots and f.side == "above" and f.k == 1 then row = f end end
check(row and row:IsVisible() and row._points[1] and row._points[1][2]:GetParent() == ns.hud, "the first row sits on the HUD itself")
check(near(ns.hud:GetWidth(), db.bars.power.width) and near(ns.hud:GetHeight(), db.bars.power.height), "the HUD keeps the bar's room, to be grabbed when unlocked")
db.icons.shape = "CELL"; ns:LayoutIcons()
local cw = ns:ComboCellSize()
check(near(cw, (db.bars.combo.width - 4 * ns.CP_GAP) / 5), "Rectangular icons: the usual cell size without a combo row")
db.icons.shape = "SQUARE"; ns:LayoutIcons()
ns:RemoveIcon("above", 1, 1)
check(not ns.hud:IsShown(), "the last icon removed: nothing to show")
local okAdd, msgAdd = ns:AddIcon("above", 1, 6774)
check(ns.hud:IsShown(), "an icon added: shown again (" .. tostring(okAdd) .. " " .. tostring(msgAdd) .. ")")
ns:ClearRow("above", 1)
check(not ns.hud:IsShown(), "the row cleared: hidden")
for i = 1, 5 do db.disabled["cp" .. i] = false end
ns:SetElementOn("energy", true)
check(ns.hud:IsShown() and ns.comboRow:IsShown() and ns.powerBar:IsShown(), "all back")

out(("\n%d failure(s)"):format(fails))
return fails
