-- 1.4: warrior, rage, prediction, icon rows, out-of-combat fade, icon editor
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function label(f) return (f._textFS and f._textFS._text) or (f.text and f.text._text) end
local function findButton(text)
  for _, f in ipairs(M.frames) do
    if f._kind == "Button" and f:IsVisible() and label(f) == text then return f end
  end
end
local function rect(r) M.ResetLayout(); local l, b, w, h = M.Rect(r); return l, b, w, h end
-- the list of pages on the left of the options: each button knows its page (3 = Icons)
local function nav(i)
  for _, f in ipairs(M.frames) do
    if f._kind == "Button" and f.page == i and f.name and f.desc and f:IsVisible() then return f end
  end
end
-- a visible slider on the same line as a visible label (General page: label left, slider right)
local function sliderBesideLabel(text)
  local fs
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text == text and r._parent:IsVisible() and r:IsShown() then fs = r end
  end
  if not fs then return end
  local _, lb, _, lh = M.Rect(fs)
  local best, bestD
  for _, f in ipairs(M.frames) do
    if f._kind == "Slider" and f:IsVisible() and f:GetParent() == fs._parent then
      local _, sb, _, sh = M.Rect(f)
      local d = math.abs((sb + sh / 2) - (lb + lh / 2))
      if d < 14 and (not bestD or d < bestD) then best, bestD = f, d end
    end
  end
  return best
end

local ns = {}
S.class = "WARRIOR"; S.locale = "frFR"; S.rage = 0
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local hud, power, comboRow, layer = ns.hud, ns.powerBar, ns.comboRow, ns.iconLayer
local costClip
for _, f in ipairs(M.frames) do if f._parent == power and f._clips then costClip = f end end
local costTex
for _, r in ipairs(M.regions) do if r._parent and r._parent._parent == costClip then costTex = r end end
local function rows()
  local t = {}
  for _, f in ipairs(M.frames) do if f._parent == layer and f._kind ~= "AuraContainer" then t[#t + 1] = f end end
  return t
end
local function slots(row)
  local t = {}
  for _, f in ipairs(M.frames) do if f._parent == row and f:IsShown() then t[#t + 1] = f end end
  return t
end
local function lit(f) return f:IsShown() and not f.icon._desat and f._alpha == 1 end
local function costWidth() if not costClip:IsShown() then return 0 end local _, _, w = rect(costTex); return w end

out("== warrior HUD")
check(ns.isWarrior and ns.enabled and hud:IsShown(), "HUD shown for a warrior")
check(not comboRow:IsShown() and hud._h == 24, "no combo row: the HUD is the rage bar alone")
local c = power._barcolor
check(near(c[1], .663) and c[2] == 0 and c[3] == 0, "rage bar color sampled from the screenshot (169, 0, 0)")
S.rage = 64; M.Fire("UNIT_POWER_FREQUENT", "player", "RAGE")
check(M.reveal(power._value) == 64 and power._max == 100, "rage 64 / 100")
local registered = {}
for f in pairs(M.eventFrames) do for e in pairs(f._events or {}) do registered[e] = true end end
check(registered.UNIT_AURA and registered.CURRENT_SPELL_CAST_CHANGED and registered.UNIT_SPELLCAST_START and not registered.UNIT_HEALTH,
  "warrior events: auras, queued attacks, casts; no combo point events")
check(ns:GetProfileName() == "Guerrier" and ns.db == ClaraComboPointsDB.profiles.WARRIOR, "warrior profile in use")
local _, py = rect(power); local _, hy = rect(hud)
local rpx = 1359 / 768
M.ResetLayout()

out("== default tracker: Sunder Armor, Demoralizing Shout, Hamstring, Battle Shout, Bloodrage")
local r = rows()
local row1 = r[1]
local s1 = slots(row1)
check(#r >= 1 and row1:IsShown() and #s1 == 5, "one row of 5 icons")
local wanted = { "Sunder Armor", "Demoralizing Shout", "Hamstring", "Battle Shout", "Bloodrage" }
local names = {}
for i, s in ipairs(s1) do names[i] = s.name end
check(table.concat(names, ",") == table.concat(wanted, ","), "in the screenshot's order: " .. table.concat(names, ", "))
local sl, sb, sw, sh = rect(s1[1])
check(ns.db.icons.shape == "SQUARE" and near(sw, 55) and near(sh, 55), "square icons by default (55 x 55)")
ns.db.icons.size = 25; ns:LayoutIcons(); M.ResetLayout() -- (the checks below: 25)
ns.db.icons.shape = "FILL"; ns:LayoutIcons(); M.ResetLayout()
sl, sb, sw, sh = rect(s1[1])
local pl, pb, pw, ph = rect(power)
check(near(sw, 56) and near(sh, 25), "bar width: icon cells shaped like the combo points (56 x 25)")
check(near(sb - (pb + ph), 4) and near(sl, pl), "row sits where the combo points would be (4 above the bar)")
local tl, tb, tw, th = rect(s1[1].icon)
check(near(tw, 56) and near(th, 25) and s1[1].icon._tc[3] > 0.08, "icon fills the cell, cropped (not stretched)")
local pieces, corner = 0, nil
for _, t in ipairs(s1[1].frame) do if t._file == "ATLAS:UI-HUD-ActionBar-IconFrame" then pieces = pieces + 1 end end
check(pieces == 8, "action button frame around the icon, cut to fit the cell (8 pieces)")
local _, _, cw0, ch0 = rect(s1[1].frame[1])
check(near(cw0, 25 * .22) and near(ch0, 25 * .22), "frame corners keep their shape (" .. cw0 .. " x " .. ch0 .. ")")

out("== auras light their icon")
S.target = { hostile = true }
S.auras = {
  target = { { name = "Sunder Armor", icon = 132363, applications = 3, duration = 30, expirationTime = 20, harmful = true, spellId = 11597 } },
  player = { { name = "Battle Shout", icon = 132333, applications = 0, duration = 120, expirationTime = 110, spellId = 6673 } },
}
M.now = 0
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
local sunder, demo, battle = s1[1], s1[2], s1[4]
check(lit(sunder) and lit(battle) and not lit(demo), "Sunder Armor (target debuff) and Battle Shout (own buff) active, Demoralizing Shout missing")
check(sunder.count._text == 3, "Sunder Armor: 3 stacks")
check(sunder.cd._cd and sunder.cd._cd[1] == -10 and sunder.cd._cd[2] == 30 and not sunder.cd._hideNumbers and sunder.cd._abbrev == 120,
  "time left on the game's cooldown swipe and countdown (2m / 1:59 / 59)")
check(not sunder.cd._reverse, "swipe like a cooldown by default")
check(demo.icon._desat == true and demo._alpha == .45 and not demo.cd._cd, "missing aura grayed out")
ns.db.icons.reverse = true; ns:UpdateIcons()
check(sunder.cd._reverse == true, "option: reversed swipe on auras")
ns.db.icons.reverse = false; ns:UpdateIcons()

out("== aura events are cheap")
M.auraLookups = 0
for _ = 1, 10 do M.Fire("UNIT_AURA", "player") end
check(M.auraLookups == 0, "UNIT_AURA bursts only mark the icons")
M.Frame(0.016)
local perUpdate = M.auraLookups
check(perUpdate > 0 and perUpdate <= 15, "one refresh on the next frame (" .. perUpdate .. " lookups for 5 icons)")
M.auraLookups = 0
for _ = 1, 60 do M.Frame(0.016) end
check(M.auraLookups == 0, "no lookups without aura events")

out("== target change, and auras hidden from addons")
S.target = nil; M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
check(not lit(sunder) and lit(battle), "no target: target debuffs off, own buffs stay")
S.target = { hostile = true }
S.secretAuras = true
local ok, err = pcall(function() M.Fire("UNIT_AURA", "target"); M.Frame(0.016) end)
local function auraShown(slot)
  for _, f in ipairs(M.frames) do
    if f._auraButton and f._points and f._points[1] and f._points[1][2] == slot and f:IsVisible() then return f end
  end
end
local sb, bb = auraShown(sunder), auraShown(battle)
check(ok and not lit(sunder) and sb and sb._cd._cd[2] == 30 and M.reveal(sb._count._text) == 3 and bb and bb._cd._cd[2] == 120 and not auraShown(demo),
  "auras hidden from addons (combat): the game's own aura buttons show them over the icons, with time and stacks " .. tostring(err))
S.secretAuras = false; S.secretFields = true
ok, err = pcall(function() M.Fire("UNIT_AURA", "target"); M.Frame(0.016) end)
check(ok and lit(sunder) and M.reveal(sunder.count._text) == "x" and sunder.cd._cd and sunder.cd._cd[2] == 30,
  "secret stacks and time: stacks through the game's text, swipe from the game's duration object " .. tostring(err))
S.secretFields = false
M.Fire("UNIT_AURA", "target"); M.Frame(0.016)

out("== look options")
ns.db.icons.shape = "SQUARE"; ns:LayoutIcons()
sl, sb, sw, sh = rect(s1[1])
local rl, rb, rw, rh = rect(row1)
check(near(sw, 25) and near(sh, 25) and near(rw, 5 * 25 + 4 * 3), "square: 25 x 25 icons, row as wide as its icons")
check(near(rl + rw / 2, pl + pw / 2), "square row centred on the bar")
ns.db.icons.size = 40; ns:LayoutIcons()
sl, sb, sw, sh = rect(s1[1])
check(near(sw, 40) and near(sh, 40), "size 40")
ns.db.icons.shape = "CELL"; ns:LayoutIcons()
sl, sb, sw, sh = rect(s1[1])
rl, rb, rw, rh = rect(row1)
check(near(sw, 56) and near(sh, 25) and near(rw, 5 * 56 + 4 * 3), "combo point cells: 56 x 25, whatever the size setting")
ns.db.rows.above[1][6] = 772; ns:LayoutIcons()
sl, sb, sw, sh = rect(s1[1])
rl, rb, rw, rh = rect(row1)
check(near(sw, 56) and near(sh, 25) and near(rw, 6 * 56 + 5 * 3) and near(rl + rw / 2, pl + pw / 2), "6 icons: still combo point cells, row centred")
table.remove(ns.db.rows.above[1], 6)
ns.db.icons.shape = "FILL"; ns:LayoutIcons()
sl, sb, sw, sh = rect(s1[1])
check(near(sw, 56) and near(sh, 40), "back to filling the bar: full width, 40 tall")
ns.db.icons.size = 25; ns:LayoutIcons()
ns.db.icons.timers = false; ns:UpdateIcons()
check(sunder.cd._hideNumbers == true, "countdown numbers can be turned off")
ns.db.icons.timers = true
ns.db.icons.missing = false; ns:UpdateIcons()
check(not demo:IsShown() and sunder:IsShown(), "missing auras can be hidden (the others keep their place)")
ns.db.icons.missing = true; ns:UpdateIcons()

out("== rows above grow upward, rows below grow downward")
ns.db.rows.above[2] = { 6774, 1943 }
ns.db.rows.below[1] = { 6673 }
ns.db.rows.below[3] = { 2687, 1715, 7386 }
ns:LayoutIcons()
local byCount = {}
for _, f in ipairs(rows()) do if f:IsShown() then byCount[#slots(f)] = f end end
local a2, b1, b3 = byCount[2], byCount[1], byCount[3]
local _, a1b, _, a1h = rect(row1)
local _, a2b = rect(a2)
local _, b1b, _, b1h = rect(b1)
local _, b3b, _, b3h = rect(b3)
check(near(a2b - (a1b + a1h), 4), "top 2 sits on top 1")
check(near(pb - (b1b + b1h), 4), "bottom 1 hangs under the bar")
check(near(b1b - (b3b + b3h), 4), "bottom 3 hangs under bottom 1 (empty bottom 2 takes no room)")
ns.db.rows.above[1] = {}
ns:LayoutIcons()
_, a2b = rect(a2)
check(near(a2b - (pb + ph), 4), "empty top 1: top 2 sits on the bar")
ns:ResetIcons()
check(#ns.db.rows.above[1] == 5 and #ns.db.rows.above[2] == 0 and #ns.db.rows.below[3] == 0, "default icons restored")

out("== rage about to be spent (warrior)")
S.rage = 50; M.Fire("UNIT_POWER_FREQUENT", "player", "RAGE")
check(costWidth() == 0, "nothing queued: no marker")
S.queued = 11567; M.Fire("CURRENT_SPELL_CAST_CHANGED", false)
local fl, _, fw = rect(power:GetStatusBarTexture())
local cl, _, cw = rect(costTex)
check(near(cw, 15 / 100 * 292) and near(cl + cw, fl + fw), "Heroic Strike queued: 15 rage marked at the end of the bar")
S.queued = nil; M.Fire("CURRENT_SPELL_CAST_CHANGED", false)
check(costWidth() == 0, "swing done: marker gone")
S.queued = 845; M.Fire("CURRENT_SPELL_CAST_CHANGED", false)
check(near(costWidth(), 20 / 100 * 292), "Cleave queued: 20 rage")
S.casting = 1464; M.Fire("UNIT_SPELLCAST_START", "player")
check(near(costWidth(), 35 / 100 * 292), "Slam cast with Cleave queued: 35 rage")
S.queued = nil
M.Frame(0.2)
check(near(costWidth(), 15 / 100 * 292), "Cleave unqueued without an event: the safety refresh catches it, Slam alone 15")
S.casting = nil; M.Fire("UNIT_SPELLCAST_STOP", "player")
check(costWidth() == 0, "cast over: marker gone")
S.rage = 5; M.Fire("UNIT_POWER_FREQUENT", "player", "RAGE")
S.queued = 11567; M.Fire("CURRENT_SPELL_CAST_CHANGED", false)
cl, _, cw = rect(costTex)
check(costClip._clips and cl < pl, "more cost than rage: the marker runs past the bar start, cut by the clip frame")
ns:SetPredict(false)
check(costWidth() == 0, "prediction can be turned off")
ns:SetPredict(true)
check(near(costWidth(), 15 / 100 * 292), "and on again")
S.queued = nil; M.Fire("CURRENT_SPELL_CAST_CHANGED", false)
S.secret = true
ok, err = pcall(function() S.queued = 11567; M.Fire("CURRENT_SPELL_CAST_CHANGED", false); M.Frame(0.2) end)
check(ok and near(costWidth(), 15 / 100 * 292), "secret rage: marker still drawn from the bar's fill " .. tostring(err))
S.secret = false; S.queued = nil; M.Fire("CURRENT_SPELL_CAST_CHANGED", false)

out("== out of combat fade")
check(ns.db.fadeOOC == false, "out-of-combat fade off by default")
ns.db.fadeOOC = true; ns:ApplyFade()
check(near(power._alpha, .2) and near(layer._alpha, .2), "out of combat: bar and icons at 20 %")
M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true
check(power._alpha == 1 and layer._alpha == 1, "in combat: full opacity")
M.Fire("PLAYER_REGEN_ENABLED"); S.inCombat = false
check(near(power._alpha, .2), "combat over: faded again")
ns.db.oocPower, ns.db.oocTop = .5, .1; ns:ApplyFade()
check(near(power._alpha, .5) and near(layer._alpha, .1) and near(comboRow._alpha, .1), "bar and combo points / icons have their own opacity")
ns:SetLocked(false)
check(power._alpha == 1, "unlocked: full opacity to place it")
ns:SetLocked(true)
ns.db.fadeOOC = false; ns:ApplyFade()
check(power._alpha == 1 and layer._alpha == 1, "fade can be turned off")
ns.db.fadeOOC = true; ns.db.oocPower, ns.db.oocTop = .2, .2; ns:ApplyFade()

out("== options: fade preview")
M.timers = {}
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
check(power._alpha == 1, "options open: full opacity to judge colors")
nav(1):Click() -- General: the opacity group
local oocPowerSlider = sliderBesideLabel(ns.L.RAGE_BAR) -- "Barre de rage": a warrior has only rage
check(oocPowerSlider ~= nil and oocPowerSlider:GetParent() ~= panel, "General page: out-of-combat slider of the rage bar, beside its label")
oocPowerSlider:SetValue(35)
check(ns.db.oocPower == .35 and near(power._alpha, .35), "moving an out-of-combat slider shows the faded look")
M.RunTimer(#M.timers)
check(power._alpha == 1, "then back to full opacity")

out("== options: icon editor")
nav(3):Click() -- Icons
local add = findButton("Ajouter > Haut 1")
check(add ~= nil, "Add button names the selected row")
local input
for _, f in ipairs(M.frames) do if f._kind == "EditBox" and f:IsVisible() and f._maxLetters == 80 then input = f end end
local status
for _, r in ipairs(M.regions) do if r._kind == "FontString" and r._parent == layer then end end
local function statusText()
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._parent:IsVisible() and type(r._text) == "string" and r._tc and (r._tc[1] == .4 or r._tc[1] == 1 and r._tc[2] == .45) then return r._text end
  end
end
input:SetText("1943"); add:Click()
check(ns.db.rows.above[1][6] == 1943 and statusText() == "Rupture ajouté (Haut 1).", "spell ID added to the row (" .. tostring(statusText()) .. ")")
input:SetText("Sunder Armor"); input._scripts.OnEnterPressed(input)
check(#ns.db.rows.above[1] == 6 and statusText() == "Sunder Armor est déjà dans cette ligne.", "same spell twice refused (any rank)")
input:SetText("999999"); add:Click()
check(statusText() == "Aucun sort avec l'ID 999999.", "unknown ID refused")
local lines = {}
for _, f in ipairs(M.frames) do
  if f._kind == "Button" and f._w == 680 and f:IsVisible() then lines[#lines + 1] = f end
end
check(#lines == 6, "6 row lines (3 above, 3 below)")
lines[4]:Click() -- Bas 1
check(findButton("Ajouter > Bas 1") ~= nil, "clicking a row selects it")
input:SetText("Heroic Strike"); add:Click()
check(ns.db.rows.below[1][1] == 11567, "known name stored as its spell ID (follows the client language)")
input:SetText("[Enrage]"); add:Click()
check(ns.db.rows.below[1][2] == "Enrage" and statusText():find("suivi par son nom"), "unknown name tracked by name")
M.Frame(0.016) -- icon states are read on the next frame
local _, bottom1 = nil, nil
for _, f in ipairs(rows()) do if f:IsShown() and #slots(f) == 2 then bottom1 = f end end
check(bottom1 ~= nil and slots(bottom1)[2].spellIcon == "Interface\\Icons\\INV_Misc_QuestionMark", "row shown on the HUD, unknown icon as a question mark")
local icons = {}
for _, f in ipairs(M.frames) do if f._parent == lines[3] and f._kind == "Button" and f:IsShown() then icons[#icons + 1] = f end end
check(#icons == 6, "top 1 line shows its 6 icons")
local function row(side, k) return table.concat(ns.db.rows[side][k], ",") end
local function drag(from, to, dx)
  M.mouseDown = true
  from._scripts.OnDragStart(from)
  M.CursorOn(to, dx); M.Frame(0.016)
end
local function drop(from) M.mouseDown = false; from._scripts.OnDragStop(from) end
drag(icons[2], icons[1])
check(icons[1].landing:IsShown() and icons[1].spell == 1160 and icons[2].spell == 7386, "dragging: the icons make room live (Demoralizing Shout shown first)")
check(ns.db.rows.above[1][1] == 7386, "nothing saved before the drop")
drop(icons[2])
check(row("above", 1) == "1160,7386,1715,6673,2687,1943", "dropped: moved left (" .. row("above", 1) .. ")")
drag(icons[1], icons[3])
drop(icons[1])
check(row("above", 1) == "7386,1715,1160,6673,2687,1943", "dragged right (" .. row("above", 1) .. ")")
drag(icons[2], icons[6], 60)
drop(icons[2])
check(row("above", 1) == "7386,1160,6673,2687,1943,1715", "dropped past the last icon: goes last (" .. row("above", 1) .. ")")
local bas1 = {}
for _, f in ipairs(M.frames) do if f._parent == lines[4] and f._kind == "Button" then bas1[#bas1 + 1] = f end end
drag(icons[6], bas1[1])
check(bas1[1].landing:IsShown() and bas1[1].spell == 1715 and not icons[6]:IsShown(), "dragging to another row: room made there, gone from its row")
drop(icons[6])
check(row("above", 1) == "7386,1160,6673,2687,1943" and row("below", 1) == "1715,11567,Enrage", "dropped into Bas 1 (" .. row("below", 1) .. ")")
check(findButton("Ajouter > Bas 1") ~= nil, "the row it went to is selected")
local hudRows = 0
for _, f in ipairs(rows()) do if f:IsShown() then hudRows = hudRows + 1 end end
check(hudRows == 2, "HUD updated at once (top 1 and bottom 1)")
drag(icons[1], input.holder)
drop(icons[1])
check(row("above", 1) == "7386,1160,6673,2687,1943", "released outside the rows: nothing moves")
drag(bas1[1], icons[1])
M.mouseDown = false; M.Frame(0.016)
check(row("above", 1) == "1715,7386,1160,6673,2687,1943" and row("below", 1) == "11567,Enrage", "drop also seen when the button that started the drag went away")
ns.db.rows.below[1] = { 7386 }
ns:LayoutIcons(); panel:Refresh()
drag(icons[2], bas1[1])
drop(icons[2])
check(row("above", 1) == "1715,7386,1160,6673,2687,1943" and row("below", 1) == "7386", "same spell already in the target row: refused")
ns.db.rows.below[1] = {}
ns:LayoutIcons(); panel:Refresh()
icons[6]:Click("RightButton")
check(#ns.db.rows.above[1] == 5 and ns.db.rows.above[1][5] == 2687, "right-click removes it")
icons[1]._scripts.OnEnter(icons[1])
check(GameTooltip._shown and GameTooltip._lines[1] == "spell:1715", "tooltip shows the spell")
icons[1]._scripts.OnLeave(icons[1])
for i = 1, 20 do ns.db.rows.below[2][i] = 6774 + i end
lines[5]:Click()
input:SetText("1943"); add:Click()
check(#ns.db.rows.below[2] == 20 and statusText() == "Ligne pleine (20 icônes maximum).", "20 icons max per row")
findButton("Vider la ligne"):Click()
check(#ns.db.rows.below[2] == 0, "clear row")
findButton("Icônes par défaut"):Click()
check(#ns.db.rows.above[1] == 5 and #ns.db.rows.below[1] == 0, "default icons")
panel:Hide()

out("== druid: bear form, rage, Maul and Frenzied Regeneration")
local nd = {}
M.eventFrames = {}
S.class = "DRUID"; S.powerType = 1; S.rage = 40
ClaraComboPointsDB = nil
M.LoadAddon(ADDON_DIR, nd)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local dpower = nd.powerBar
local dclip
for _, f in ipairs(M.frames) do if f._parent == dpower and f._clips then dclip = f end end
local dtex
for _, rr in ipairs(M.regions) do if rr._parent and rr._parent._parent == dclip then dtex = rr end end
local function dcost() if not dclip:IsShown() then return 0 end local _, _, w = rect(dtex); return w end
check(nd.hud:IsShown() and M.reveal(dpower._value) == 40 and nd.comboRow:IsShown(), "bear form: shown, rage 40, combo row kept")
S.queued = 9881; M.Fire("CURRENT_SPELL_CAST_CHANGED", false)
check(near(dcost(), 15 / 100 * 292), "Maul queued: 15 rage")
S.queued = nil; M.Fire("CURRENT_SPELL_CAST_CHANGED", false)
M.now = 100
S.auras = { player = { { name = "Frenzied Regeneration", icon = 132091, applications = 0, duration = 10, expirationTime = 110 } } }
M.Fire("UNIT_AURA", "player")
check(dcost() == 0, "aura event: read on the next frame")
M.Frame(0.016)
check(near(dcost(), 292), "Frenzied Regeneration: up to 100 rage over 10 s (whole bar)")
M.now = 107.5; M.Frame(0.2)
check(near(dcost(), 30 / 100 * 292), "2.5 s left: 3 ticks, 30 rage")
M.now = 111; M.Frame(0.2)
check(dcost() == 0, "over: marker gone")
S.auras = nil
S.powerType = 3; M.Fire("UNIT_DISPLAYPOWER", "player")
S.queued = 9881; M.Fire("CURRENT_SPELL_CAST_CHANGED", false)
check(dcost() == 0 and dpower._barcolor[2] == 1, "cat form: energy, no rage marker")
S.queued = nil
nd.db.rows.above[1] = { 6774 }
nd:LayoutIcons()
local drow
for _, f in ipairs(M.frames) do if f._parent == nd.iconLayer and f._kind ~= "AuraContainer" and f:IsShown() then drow = f end end
local _, cb, _, ch = rect(nd.comboRow)
local _, rb = rect(drow)
check(near(rb - (cb + ch), 4), "druid icon row sits above the combo points")

out(string.format("\n%d failure(s)", fails))
return fails
