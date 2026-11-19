-- Water Shield Tracker, built in (Modules/WaterShieldTracker): a shaman's Water Shield charges on the spell's icon;
-- missing: red, "Refresh!"; a click recasts it (a secure button: its frame protected). In combat nothing of the frame
-- is asked of the game (each aura change; what changes in a fight done once it is over). Its card's boxes, its page,
-- /ws
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70959", "Nov 17 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }
M.TEMPLATES.UIRadioButtonTemplate = M.TEMPLATES.UIRadioButtonTemplate or function(b) end -- (the game's round box)
GetCursorPosition = GetCursorPosition or function() return 0, 0 end
local SpellInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function(id) if id == 409941 then return { name = "Water Shield", spellID = id, iconID = 132315 } end return SpellInfo(id) end

local ns = {}
S.class = "SHAMAN"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
local function Texts(f)
  local t = {}
  for _, r in ipairs(M.regions) do if r._parent == f and r._kind == "FontString" and r._shown ~= false and r._text then t[#t + 1] = tostring(r._text) end end
  return table.concat(t, " | ")
end

out("== a shaman: the icon, Water Shield missing then on")
check(ns:QolRuns("watershield"), "the module runs")
local frame = ns.WaterShield.frame
check(frame and frame:IsShown() and frame._protected, "its icon shown, its frame protected (the secure button inside)")
check(Texts(frame):find("Refresh!", 1, true) and Texts(frame):find("0", 1, true), "missing: 0 and \"Refresh!\" (" .. Texts(frame) .. ")")
local tex
for _, r in ipairs(M.regions) do if r._parent == frame and r._kind == "Texture" and r._layer == "ARTWORK" then tex = r end end
check(tex and tex._desat == true, "the icon red (desaturated, tinted)")
S.auras = { player = { { name = "Water Shield", spellId = 409941, applications = 3 } } }
M.Fire("UNIT_AURA", "player")
check(Texts(frame) == "3", "on: its 3 charges, no reminder (" .. Texts(frame) .. ")")
check(tex._desat == false, "the icon in its colors")
local cast = _G.ClaraWaterShieldCastButton
check(cast and cast:GetAttribute("type1") == "spell" and cast:GetAttribute("spell") == "Water Shield", "a click casts Water Shield")

out("== in combat: nothing refused")
M.blocked = {}
S.inCombat = true
for i = 1, 50 do
  S.auras.player[1].applications = 3 - (i % 3)
  M.Fire("UNIT_AURA", "player")
end
check(#M.blocked == 0, ("each aura change: none refused (%d)%s"):format(#M.blocked, M.blocked[1] and (": " .. M.blocked[1]) or ""))

out("== its page, changed in a fight: done once it is over")
local page, parts = ns.WaterShieldPage, ns.WaterShieldParts
check(page and ns.waterShieldCategory, "its page, in Clara's options")
page:Show()
if page._scripts and page._scripts.OnShow then page._scripts.OnShow(page) end
check(parts.show and parts.locked and parts.clickCast and parts.allClasses and parts.size and parts.scale and parts.fontSize and parts.color
  and parts.reset and parts.radios and parts.radios.TOPLEFT, "its boxes, sliders, color, text place, reset")
parts.show:Click()
parts.size:SetValue(70)
SlashCmdList.CLARAWATERSHIELD("reset")
check(#M.blocked == 0, "hidden, sized, put back in combat: nothing refused (" .. #M.blocked .. ")")
check(frame:IsShown(), "still shown while the fight lasts")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(not frame:IsShown(), "the fight over: hidden")
check(math.abs((frame:GetWidth() or 0) - 70) < 0.01, "and sized (" .. tostring(frame:GetWidth()) .. ")")
parts.show:Click()
check(frame:IsShown(), "shown again")

out("== its card's boxes, /ws")
local sw = {}
for _, s in ipairs(ns.qolSwitches.watershield or {}) do sw[s.label] = s end
check(sw.WSH_SW_LOCK and sw.WSH_SW_CLICK, "Locked, A click recasts it")
sw.WSH_SW_CLICK.set(false)
check(cast:GetAttribute("type1") == nil, "the click off: no cast")
sw.WSH_SW_CLICK.set(true)
SlashCmdList.CLARAWATERSHIELD("lock")
check(ClaraWaterShieldDB.locked == true and sw.WSH_SW_LOCK.get() == true, "/ws lock: locked")
parts.radios.TOPLEFT:Click()
check(ClaraWaterShieldDB.textAnchor == "TOPLEFT", "the number at the top left")
check(type(ClaraWaterShieldDB) == "table" and ClaraWaterShieldDB.size == 70, "kept in ClaraWaterShieldDB")
out(string.format("\n%d failure(s)", fails))
return fails
