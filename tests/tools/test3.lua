local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local ns = {}
S.class = "DRUID"; S.powerType = 0 -- caster form: mana
M.LoadAddon(ADDON_DIR, ns)
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local hud = ns.hud
local bars, energyBar = {}, ns.powerBar
for _, f in ipairs(M.frames) do
  if f._kind == "StatusBar" and f._parent == ns.comboRow then bars[#bars + 1] = f end
end
-- caster form: the mana bar alone (combo points, energy and icons only in Cat and Bear Form)
local function casterOnly()
  return hud:IsShown() and ns.manaBar:IsShown() and not ns.comboRow:IsShown() and not energyBar:IsShown() and not ns.iconLayer:IsShown()
end
table.sort(bars, function(a, b) return a._min < b._min end)
local function cp() return M.reveal(bars[1]._value) end
local function shapeshift(pt) S.powerType = pt; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Fire("UNIT_DISPLAYPOWER", "player") end

out("== druid")
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
check(ns.enabled and ns.isDruid, "druid recognised")
check(casterOnly(), "caster form: only the mana bar")
local registered = {}
for f in pairs(M.eventFrames) do for e in pairs(f._events or {}) do registered[e] = true end end
check(registered.UNIT_DISPLAYPOWER and registered.UPDATE_SHAPESHIFT_FORM and registered.PLAYER_TARGET_CHANGED, "druid events registered")

S.target = { cp = 3, hostile = true }; S.energy = 80
M.Fire("PLAYER_TARGET_CHANGED")
shapeshift(3) -- cat form: energy
check(hud:IsShown(), "cat form: HUD shown")
check(cp() == 3 and M.reveal(energyBar._value) == 80, "values refreshed on showing (3 points, 80 energy)")
S.target.cp = 4; M.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
check(cp() == 4, "combo points update in cat form")
S.energy = 20; M.Frame(0.016)
check(M.reveal(energyBar._value) == 20, "energy updates in cat form")

S.rage = 37
shapeshift(1) -- bear form: rage
check(hud:IsShown(), "bear form (rage): HUD shown")
check(M.reveal(energyBar._value) == 37 and energyBar._max == 100, "bear form: the bar shows rage (37 / 100)")
local rc = energyBar._barcolor
check(math.abs(rc[1] - .663) < .001 and rc[2] == 0 and rc[3] == 0, "bear form: rage color (169, 0, 0)")
check(cp() == 4, "bear form: the target's combo points still show")
local bgShown = 0
for i = 1, 5 do if bars[i].bg:IsShown() then bgShown = bgShown + 1 end end
check(bgShown == 0, "bear form: empty cells not drawn (transparent)")
S.rage = 52; M.Fire("UNIT_POWER_FREQUENT", "player", "RAGE")
check(M.reveal(energyBar._value) == 52, "rage updates")
S.target.cp = 0; M.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
check(cp() == 0, "bear form, no combo points: nothing on the top row")
S.target.cp = 5; S.energy = 100
shapeshift(3)
bgShown = 0
for i = 1, 5 do if bars[i].bg:IsShown() then bgShown = bgShown + 1 end end
check(hud:IsShown() and cp() == 5 and M.reveal(energyBar._value) == 100 and bgShown == 5, "back in cat: energy, 5 points and the empty cells at once")
check(energyBar._barcolor[1] == 1 and energyBar._barcolor[2] == 1, "back in cat: energy color")
shapeshift(0) -- caster form
check(casterOnly(), "caster form: only the mana bar")
S.target.cp = 2
M.Frame(0.5)
check(cp() == 5, "hidden HUD does no work")
shapeshift(3)
check(cp() == 2, "back in cat: re-read")
S.target.cp = 5; M.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")

out("== moving and configuring from caster form")
shapeshift(0)
ns:SetLocked(false)
check(hud:IsShown(), "unlocked: shown in caster form so it can be moved")
ns:SetLocked(true)
check(casterOnly(), "locked again: only the mana bar in caster form")
SlashCmdList.CLARACOMBOPOINTS("")
check(hud:IsShown() and cp() == 5, "options open: preview shows the HUD with 5 points")
local catBox
for _, r in ipairs(M.regions) do
  if r._kind == "FontString" and r._text == "Afficher seulement en forme de félin et d'ours" then catBox = r._parent end
end
check(catBox and catBox:GetChecked() == true, "'Cat Form only' checkbox present and ticked")
M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true
check(not ns.preview and hud:IsShown() and cp() == 5, "combat ends the preview, but the HUD stays while the options are open")
S.inCombat = false
local previewBtn
for _, f in ipairs(M.frames) do
  if f._kind == "Button" and f._textFS and f._textFS._text == "Aperçu (tout allumé)" then previewBtn = f end
end
previewBtn:Click(); previewBtn:Click()
check(not ns.preview and hud:IsShown(), "preview toggled off: HUD still shown while the options are open")
ClaraComboPointsOptions:Hide()
check(casterOnly(), "options closed: only the mana bar again in caster form")
S.inCombat = true
SlashCmdList.CLARACOMBOPOINTS("")
check(hud:IsShown() and not ns.preview, "options opened in combat: HUD shown (no preview)")
ClaraComboPointsOptions:Hide(); S.inCombat = false
check(casterOnly(), "closed again: only the mana bar")

SlashCmdList.CLARACOMBOPOINTS("")
catBox:Click()
ClaraComboPointsOptions:Hide()
check(ns.db.druidCatOnly == false and hud:IsShown(), "unticked: shown in caster form with the options closed")
shapeshift(1)
check(hud:IsShown(), "still shown in bear form")
ns:SetDruidCatOnly(true)
check(hud:IsShown(), "ticked again: still shown in bear form")
shapeshift(0)
check(casterOnly(), "ticked again: only the mana bar in caster form")

out("== hidden HUD does no work")
local calls = 0
local gcp, up = GetComboPoints, UnitPower
GetComboPoints = function(...) calls = calls + 1; return gcp(...) end
UnitPower = function(u, p, ...) if p ~= 0 then calls = calls + 1 end; return up(u, p, ...) end -- (mana is read in every form)
for _ = 1, 20 do M.Fire("UNIT_HEALTH", "target") end
M.Fire("PLAYER_TARGET_CHANGED"); M.Fire("UNIT_POWER_FREQUENT", "player", "ENERGY"); M.Fire("UNIT_MAXPOWER", "player", "ENERGY")
M.Frame(0.5)
check(calls == 0, "no combo/energy reads while they are hidden (" .. calls .. ")")
GetComboPoints, UnitPower = gcp, up
S.target.cp = 2; S.energy = 42
shapeshift(3)
check(hud:IsShown() and cp() == 2 and M.reveal(energyBar._value) == 42, "cat form: everything re-read on show")
shapeshift(0)

out("== secret power type")
S.secretPowerType = true
local ok, err = pcall(shapeshift, 0)
check(ok, "secret UnitPowerType does not error " .. tostring(err))
check(hud:IsShown(), "unknown form: shown rather than hidden")
S.secretPowerType = false
shapeshift(0)

out("== reset keeps druid behaviour")
ns:ResetAll()
check(ns.db.druidCatOnly == true and casterOnly(), "reset all: Cat Form only again, only the mana bar in caster")

out(string.format("\n%d failure(s)", fails))
return fails
