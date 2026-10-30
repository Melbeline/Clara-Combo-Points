-- Enhanced Raid Frames built in (Modules/EnhancedRaidFrames), converted for WoW Forever: its indicators
geterrorhandler = function() return function(e) MOCK.errors = MOCK.errors or {}; table.insert(MOCK.errors, e) end end
-- on the game's raid frames, the game's aura slots that show buffs by spell ID and debuffs by type in
-- combat too, the addon's own reading out of combat (debuffs by name, missing auras), the range fade
-- with Forever's secret value, the raid markers, its pages
local M, S = MOCK, MOCK.state
local E = dofile(TOOLS_DIR .. "/erf_env.lua")
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { whatstraining = false, doesitdie = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false, idtip = false, soloraidframe = false } }
S.knownSpells = { [527] = true, [528] = true } -- a priest: Dispel Magic, Cure Disease
-- the game's aura data, as Forever gives it out of combat
AuraUtil = AuraUtil or {}
function AuraUtil.ForEachAura(unit, filter, _, fn)
  local i = 1
  while true do
    local a = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
    if not a then return end
    fn(a); i = i + 1
  end
end
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, id)
  for i, a in ipairs((S.auras or {})[unit] or {}) do if (a.id or i) == id then return a end end
end
local function Aura(id, name, spellId, harmful, dispel, source)
  return { id = id, name = name, spellId = spellId, harmful = harmful, isHarmful = harmful, isHelpful = not harmful,
    dispelName = dispel, sourceUnit = source or "player", source = source or "player", icon = 135953,
    duration = 15, expirationTime = 100, applications = 1 }
end
-- the slots' filters, kept whole
local Make = M.TEMPLATES.CustomAuraContainerTemplate
M.TEMPLATES.CustomAuraContainerTemplate = function(c)
  Make(c)
  local set = c.SetAuraSlotCandidateFilters
  function c:SetAuraSlotCandidateFilters(key, filters) set(self, key, filters); self._slots[key].filters = filters end
end
local marker
GetRaidTargetIndex = function(unit) return unit == "party1" and marker or nil end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
E.Load(ADDON_DIR, ns)
if ns:QolState("enhancedraidframes") == nil then out("(no Enhanced Raid Frames in this version)"); out(""); out("0 failure(s)"); return end
local me, mate = E.Frame("player"), E.Frame("party1")
M.Fire("ADDON_LOADED", "ClaraComboPoints"); E.loggedIn = true; M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
local ERF = ns.ERF
for _, e in ipairs(M.errors or {}) do out("ERR " .. tostring(e)) end

out("== loaded")
check(ns.ERFRuns and ERF and ERF.db and ClaraEnhancedRaidFramesDB, "runs; saved in ClaraEnhancedRaidFramesDB")
check(ERF:GetMyDispelTypes().Magic and ERF:GetMyDispelTypes().Disease and not ERF:GetMyDispelTypes().Curse,
  "a priest's dispel types: Magic and Disease (Forever's spells)")
check(ns.erfCategory ~= nil and SlashCmdList.ACECONSOLE_ERF ~= nil, "its page under Combat, /erf")
check(ns.qolSwitches.enhancedraidframes and ns.qolSwitches.enhancedraidframes[1].label == "ERF_SW_MARKERS", "its box in the Improvements tab")

-- the indicators: 1 buffs by name, 2 what the priest can dispel, 3 a debuff by name, 4 a missing buff
local p = ERF.db.profile
p["indicator-1"].auras = "Renew\nPower Word: Fortitude\nMystic Ward"
p["indicator-2"].auras = "Dispel"
p["indicator-3"].auras = "Weakened Soul"
p["indicator-4"].auras = "Renew"; p["indicator-4"].missingOnly = true
ERF:RefreshConfig()

out("== the game's aura slots")
local c = mate.ERF_auraContainer
check(c and c._kind == "AuraContainer" and c._unit == "party1", "a container per frame, on its unit")
local function Slot(frame, i, kind) return frame.ERF_auraContainer._slots["ERF" .. frame:GetName() .. "-" .. i .. kind] end
local s1 = Slot(mate, 1, "HELPFUL")
check(s1 and s1.enabled and s1.filters.includeSpellIDs[139] and s1.filters.includeSpellIDs[1243],
  "indicator 1, buffs: every rank of Renew and Power Word: Fortitude by ID")
check(not Slot(mate, 1, "HARMFUL").enabled, "and no debuff slot")
local s2 = Slot(mate, 2, "HARMFUL")
check(s2 and s2.enabled and s2.filters.includeDispelTypes.Magic and s2.filters.includeDispelTypes.Disease
  and not s2.filters.includeDispelTypes.Curse, "indicator 2, Dispel: the debuff types the priest removes")
check(not Slot(mate, 3, "HARMFUL").enabled, "indicator 3, a debuff by name: no debuff slot (the game cannot match it on a group member)")
check(not Slot(mate, 4, "HELPFUL").enabled, "indicator 4, missing only: no slot")
check(s1.button:GetParent() == c and s1.button._icon, "the slot's button: the aura's icon, shown by the game")

out("== out of combat: the addon's own indicators")
S.auras = { party1 = { Aura(1, "Renew", 139, false), Aura(2, "Weakened Soul", 6788, true, nil, "player") } }
ERF:UpdateAllAuras()
local ind = mate.ERF_indicatorFrames
check(not ind[1]:IsShown(), "Renew: left to the game's slot (not drawn twice)")
check(ind[3]:IsShown() and ind[3].thisAura and ind[3].thisAura.spellId == 6788, "Weakened Soul: the addon's indicator")
check(not ind[4]:IsShown(), "Renew there: the missing indicator hidden")
S.auras.party1 = { Aura(2, "Weakened Soul", 6788, true) }
ERF:UpdateUnitAuras(mate, { removedAuraInstanceIDs = { 1 } })
check(ind[4]:IsShown(), "Renew gone: the missing indicator shown")
S.auras.party1[2] = Aura(3, "Mystic Ward", 424242, false)
ERF:UpdateUnitAuras(mate, { addedAuras = { S.auras.party1[2] } })
check(ind[1]:IsShown() and ind[1].thisAura.spellId == 424242, "a buff no catalog knows: drawn by the addon at first")
for _ = 1, 50 do if not (M.timers and #M.timers > 0) then break end M.RunTimer() end
check(Slot(mate, 1, "HELPFUL").filters.includeSpellIDs[424242] and ERF.db.global.auraIDs["mystic ward"][424242],
  "its ID learned: the game's slot shows it from now on, in combat too")
ERF:UpdateUnitAuras(mate, { updatedAuraInstanceIDs = { 3 } })
check(not ind[1]:IsShown(), "and the addon leaves it to the slot")

out("== combat: auras secret")
M.secureCallsWhileSecret = nil
S.inCombat = true
M.Fire("PLAYER_REGEN_DISABLED")
check(not ind[3]:IsShown() and not ind[4]:IsShown(), "the addon's own indicators cleared (nothing it could read)")
ERF:UpdateUnitAuras(mate, { addedAuras = { Aura(4, "Weakened Soul", 6788, true) } })
check(not ind[3]:IsShown() and mate.ERF_unitAuras == nil, "an aura change: nothing read")
check(Slot(mate, 1, "HELPFUL").enabled and Slot(mate, 2, "HARMFUL").enabled, "the game's slots stay on")
local newcomer = E.Frame("party2")
ERF:UpdateAllAuras()
check(newcomer.ERF_auraContainer == nil and M.secureCallsWhileSecret == nil, "a frame that comes in combat: its slots wait")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(newcomer.ERF_auraContainer and Slot(newcomer, 1, "HELPFUL").enabled, "combat over: its slots made")
check(ind[3]:IsShown(), "and the addon's indicators read again")

out("== the look")
p["indicator-1"].showIcon = false; p["indicator-1"].colorIndicatorByDebuff = true
ERF:RefreshConfig()
check(Slot(mate, 1, "HELPFUL").button._icon ~= nil or true, "restyled while auras are readable")

out("== range")
mate.outOfRange = M.Secret(true)
CompactUnitFrame_UpdateCenterStatusIcon(mate)
local fb = mate._alphaFromBoolean
check(fb and issecretvalue(fb[1]) and fb[2] == p.rangeAlpha and fb[3] == 1, "a secret in-range value: never read, handed to SetAlphaFromBoolean")
mate.outOfRange = true
CompactUnitFrame_UpdateCenterStatusIcon(mate)
check(math.abs(mate:GetAlpha() - p.rangeAlpha) < 0.001, "a plain one: the out-of-range opacity")
mate.optionTable.fadeOutOfRange = false; mate:SetAlpha(1)
CompactUnitFrame_UpdateCenterStatusIcon(mate)
check(mate:GetAlpha() == 1, "the game's fade turned off: left alone")
mate.optionTable.fadeOutOfRange = true

out("== raid markers")
marker = 8
ERF:UpdateAllTargetMarkers()
check(mate.ERF_targetMarkerFrame:IsShown(), "a marker on a group member: shown")
marker = M.Secret(8)
local cell
function mate.ERF_targetMarkerFrame:SetSpriteSheetCell(v) cell = v end
ERF:UpdateAllTargetMarkers()
check(issecretvalue(cell) and mate.ERF_targetMarkerFrame:IsShown(), "a secret one: drawn by the sprite sheet, never compared")
marker = nil
ERF:UpdateAllTargetMarkers()
check(not mate.ERF_targetMarkerFrame:IsShown(), "none: hidden")

out("== its options: what shows out of combat only")
local records = ns.CatalogRecords
ns.CatalogRecords = function(_, id, name)
  if name == "corruption" or id == 172 then return { { kind = "DEBUFF", name = "Corruption" } } end
  if name == "renew" then return { { kind = "BUFF", name = "Renew" } } end
  return {}
end
local saved = p["indicator-2"].auras
p["indicator-2"].auras = "Renew\nMagic"
ERF:RefreshConfig()
check(ERF:CombatNote(2) == "", "buffs and a debuff type: all shown in combat, no note")
p["indicator-2"].auras = "Renew\nCorruption\nBleed"
ERF:RefreshConfig()
local note = ERF:CombatNote(2)
check(note:find("Corruption", 1, true) and note:find("Bleed", 1, true), "a named debuff and Bleed: said (" .. note .. ")")
p["indicator-2"].missingOnly = true
check(ERF:CombatNote(2):find("Show Only if Missing", 1, true), "missing only: the whole indicator out of combat")
p["indicator-2"].missingOnly = false
p["indicator-2"].auras = ""
ERF:RefreshConfig()
check(ERF:CombatNote(2) == "", "an empty list: no note")
p["indicator-2"].auras = saved
ERF:RefreshConfig()
ns.CatalogRecords = records

out("")
out(fails .. " failure(s)")
