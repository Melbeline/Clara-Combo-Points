-- idTip on WoW Forever's tooltips (they have ProcessInfo: one post call of the tooltip data covers every kind):
-- a buff's or debuff's tooltip (the buff bar's instance-ID setters, the target's by index) shows its SpellID and
-- IconID though the aura tooltip data carries no id (as Forever's); where it does carry one, one line still; an
-- aura the game keeps secret (restricted): none, and no error
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
-- (every other module off, whatever the branch has: only idTip runs)
ClaraComboPointsDB = { qol = setmetatable({ idtip = true }, { __index = function() return false end }) }

-- the game's tooltip as WoW Forever has it: ProcessInfo, its setters run the post calls, its lines' cells
local tip = GameTooltip
tip._lines = {}
function tip:GetName() return "GameTooltip" end
function tip:NumLines() return #self._lines end
local function Cell(side, i)
  local name = "GameTooltipText" .. side .. i
  _G[name] = _G[name] or { GetText = function(self) return self.text end, SetText = function(self, t) self.text = t end }
  return _G[name]
end
function tip:AddDoubleLine(l, r)
  table.insert(self._lines, tostring(l) .. "\t" .. tostring(r))
  local n = #self._lines
  Cell("Left", n):SetText(tostring(l)); Cell("Right", n):SetText(tostring(r))
end
function tip:AddLine(t)
  table.insert(self._lines, tostring(t))
  Cell("Left", #self._lines):SetText(tostring(t))
end
local postCalls = {}
TooltipDataProcessor = { AllTypes = "ALL", AddTooltipPostCall = function(kind, fn) table.insert(postCalls, fn) end }
local dataId -- (the id the game's aura tooltip data carries: nil as WoW Forever's)
local function Process(data)
  for i = 1, #tip._lines do Cell("Left", i):SetText(nil); Cell("Right", i):SetText(nil) end
  tip._lines = {}
  tip:AddLine("Mark of the Wild")
  for _, fn in ipairs(postCalls) do fn(tip, data) end
end
function tip:ProcessInfo() end
function tip:SetUnitAuraByAuraInstanceID(unit, id) Process({ type = 7, id = dataId, guid = "Player-1" }) end
function tip:SetUnitBuffByAuraInstanceID(unit, id, filter) Process({ type = 7, id = dataId, guid = "Player-1" }) end
function tip:SetUnitDebuffByAuraInstanceID(unit, id, filter) Process({ type = 7, id = dataId, guid = "Player-1" }) end
function tip:SetUnitAura(unit, index, filter) Process({ type = 7, id = dataId }) end
function tip:SetUnitBuff(unit, index, filter) Process({ type = 7, id = dataId }) end
function tip:SetUnitDebuff(unit, index, filter) Process({ type = 7, id = dataId }) end
-- the auras: the player's Mark of the Wild (instance 41), the target's Rend (a debuff)
local secret = false
local AURAS = { player = { [41] = { spellId = 9885, name = "Mark of the Wild" } },
  target = { [77] = { spellId = 11574, name = "Rend", harmful = true } } }
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, id)
  local a = AURAS[unit] and AURAS[unit][id]
  if not a then return nil end
  return { spellId = secret and M.Secret(a.spellId) or a.spellId, name = a.name, auraInstanceID = id }
end
C_UnitAuras.GetDebuffDataByIndex = function(unit, index)
  if unit == "target" and index == 1 then return { spellId = 11574, name = "Rend", auraInstanceID = 77 } end
end
C_UnitAuras.GetBuffDataByIndex = function(unit, index)
  if unit == "player" and index == 1 then return { spellId = 9885, name = "Mark of the Wild", auraInstanceID = 41 } end
end
local textures = { [9885] = 136078, [11574] = 132155 }
C_Spell.GetSpellTexture = function(id) return textures[tonumber(id)] end

S.class = "DRUID"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
local function Has(line) for _, l in ipairs(tip._lines) do if l == line then return true end end return false end
local function Count(prefix) local n = 0 for _, l in ipairs(tip._lines) do if l:find(prefix, 1, true) == 1 then n = n + 1 end end return n end

out("== a buff on the buff bar: its SpellID, though the aura tooltip data carries none (as WoW Forever's)")
check(ns:QolRuns("idtip") and #postCalls == 1, "idTip runs, its post call registered (ProcessInfo)")
tip:SetUnitAuraByAuraInstanceID("player", 41)
check(Has("SpellID\t9885") and Has("IconID\t136078"), "Mark of the Wild: SpellID 9885, IconID (" .. table.concat(tip._lines, " | ") .. ")")
tip:SetUnitBuffByAuraInstanceID("player", 41, "HELPFUL")
check(Count("SpellID") == 1 and Has("SpellID\t9885"), "the buff setter too")
tip:SetUnitDebuffByAuraInstanceID("target", 77, "HARMFUL")
check(Has("SpellID\t11574"), "a debuff on the target: Rend's SpellID")
tip:SetUnitDebuff("target", 1, "HARMFUL")
check(Has("SpellID\t11574"), "by index (the target frame's): too")
tip:SetUnitBuff("player", 1)
check(Has("SpellID\t9885"), "a buff by index: too")

out("== where the data carries the id (as the game's retail clients): one line, not two")
dataId = 9885
tip:SetUnitAuraByAuraInstanceID("player", 41)
check(Count("SpellID") == 1 and Count("IconID") == 1 and Has("SpellID\t9885"), "one SpellID, one IconID (" .. table.concat(tip._lines, " | ") .. ")")
dataId = nil

out("== an aura the game keeps secret (restricted, in combat): none, no error")
secret = true
local ok, e = pcall(tip.SetUnitAuraByAuraInstanceID, tip, "player", 41)
check(ok and Count("SpellID") == 0, "no SpellID, no error" .. (ok and "" or (": " .. tostring(e))))
secret = false
ok, e = pcall(tip.SetUnitAuraByAuraInstanceID, tip, "player", 999)
check(ok and Count("SpellID") == 0, "an aura gone: nothing")
C_UnitAuras.GetAuraDataByAuraInstanceID = function() error("unit restricted") end
ok, e = pcall(tip.SetUnitAuraByAuraInstanceID, tip, "nameplate1", 41)
check(ok, "a unit the game keeps from addons: no error")

out("== a kind unticked: none")
ClaraIdTipDB.spellEnabled = false
tip:SetUnitBuff("player", 1)
check(Count("SpellID") == 0, "SpellID unticked: not shown")
ClaraIdTipDB.spellEnabled = true

out(string.format("\n%d failure(s)", fails))
return fails
