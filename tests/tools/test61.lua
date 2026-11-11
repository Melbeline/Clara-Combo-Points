-- idTip and Solo Raid Frame built in (Modules/IdTip, Modules/SoloRaidFrame)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false } }

-- the game's tooltip as the classic clients have it: no ProcessInfo, its scripts, its lines' cells
local tip = GameTooltip
tip._lines = {}
function tip:GetName() return "GameTooltip" end
function tip:NumLines() return #self._lines end
function tip:HasScript(name) return name:find("^OnTooltipSet") ~= nil end
local scripts = {}
function tip:HookScript(name, fn) scripts[name] = fn end
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
local spell, item, unit
function tip:GetSpell() return "Sinister Strike", spell end
function tip:GetItem() return "Linen Cloth", item end
function tip:GetUnit() return "Defias Thug", unit end
local function Fresh()
  for i = 1, #tip._lines do Cell("Left", i):SetText(nil); Cell("Right", i):SetText(nil) end
  tip._lines = {}
end
local function Has(line) for _, l in ipairs(tip._lines) do if l == line then return true end end return false end
local function Count(prefix) local n = 0 for _, l in ipairs(tip._lines) do if l:find(prefix, 1, true) == 1 then n = n + 1 end end return n end

-- the game's raid-style party frame: hidden solo, shown in a group (the game's rule)
CompactPartyFrame = CreateFrame("Frame", "CompactPartyFrame", UIParent)
CompactPartyFrame:Hide()
CompactPartyFrame._protected = true -- (its unit buttons are the game's secure ones)
function SecureHandlerSetFrameRef(frame, name, ref) frame:SetAttribute("frameref-" .. name, ref) end
local gameRuns = 0
function CompactPartyFrame:UpdateVisibility()
  gameRuns = gameRuns + 1
  if S.inCombat then self._shown = IsInGroup() and true or false return end -- (the game's own secure code: allowed)
  self:SetShown(IsInGroup() and true or false)
end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)

out("== idTip")
check(ns:QolRuns("idtip") and type(ClaraIdTipDB) == "table", "runs, its settings in ClaraIdTipDB")
check(ClaraIdTipDB.enabled == true and ClaraIdTipDB.spellEnabled == true and ClaraIdTipDB.bonusEnabled == false
  and ClaraIdTipDB.traitnodeEnabled == false and ClaraIdTipDB.version == 2, "idTip's defaults (bonus and traits off)")
check(scripts.OnTooltipSetSpell and scripts.OnTooltipSetItem and scripts.OnTooltipSetUnit, "the tooltip's scripts hooked (no ProcessInfo)")
Fresh(); spell = 1752
scripts.OnTooltipSetSpell(tip)
check(Has("SpellID\t1752"), "a spell: its SpellID")
local icon = C_Spell.GetSpellTexture(1752)
check(icon == nil or Has("IconID\t" .. tostring(icon)), "and its IconID (" .. tostring(icon) .. ")")
scripts.OnTooltipSetSpell(tip)
check(Count("SpellID") == 1, "shown again: one line still")
Fresh(); item = "|cffffffff|Hitem:2589::::::::60:::::|h[Linen Cloth]|h|r"
scripts.OnTooltipSetItem(tip)
check(Has("ItemID\t2589"), "an item: its ItemID")
Fresh(); item = "|cff1eff00|Hitem:15210:1897::::::::60:::::|h[Raider's Shortsword]|h|r"
scripts.OnTooltipSetItem(tip)
check(Has("ItemID\t15210") and Has("EnchantID\t1897"), "an enchanted one: its EnchantID too")
Fresh(); unit = "target"; S.target = { hostile = true, guid = "Creature-0-5250-0-1-449-0000ABCDEF" }
scripts.OnTooltipSetUnit(tip)
check(Has("NpcID\t449"), "a creature: its NpcID")
Fresh(); S.target.guid = "Player-1-0ABC"
scripts.OnTooltipSetUnit(tip)
check(Count("NpcID") == 0, "a player: none")

out("== its settings")
local page = M.subcategories and M.subcategories.idTip
check(page and page.parent == ns.qolThemes.interface, "its page under Interface")
check(page and #page.settings == 28, "Enabled and a box per kind (" .. (page and #page.settings or 0) .. ")")
local spellBox
for _, s in ipairs(page and page.settings or {}) do if s.name == "SpellID" then spellBox = s end end
spellBox:SetValue(false)
Fresh(); spell = 1752
scripts.OnTooltipSetSpell(tip)
check(ClaraIdTipDB.spellEnabled == false and Count("SpellID") == 0, "a kind unticked: not shown")
spellBox:SetValue(true)
local switches = ns.qolSwitches.idtip
check(switches and #switches == 5 and switches[1].label == "IDT_SW_ON", "its main boxes in the Improvements tab")
switches[1].set(false)
Fresh(); scripts.OnTooltipSetSpell(tip)
check(#tip._lines == 0, "turned off there: nothing added")
switches[1].set(true)
check(SlashCmdList.CLARAIDTIP and SLASH_CLARAIDTIP1 == "/idtip", "/idtip opens its page")

out("== Solo Raid Frame")
check(ns:QolRuns("soloraidframe"), "runs")
S.group = nil
CompactPartyFrame:UpdateVisibility()
check(CompactPartyFrame:IsShown(), "solo: the raid-style party frame shown (the game had hidden it)")
S.group = "party"
CompactPartyFrame:UpdateVisibility()
check(CompactPartyFrame:IsShown(), "in a group: the game's rule")
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 100 do M.RunTimer() n = n + 1 end end
Run()
-- the game's secure state driver: its value as the game would resolve it, the snippet run as its restricted code would
local driver, drive
for f, d in pairs(M.stateDrivers) do if d[1] == "solo" then driver, drive = f, d[2] end end
check(driver ~= nil and drive == "[group] grouped; [combat] fight; solo", "a secure state driver on the group (" .. tostring(drive) .. ")")
local function Resolve()
  local state = IsInGroup() and "grouped" or (S.inCombat and "fight" or "solo")
  local snippet = driver:GetAttribute("_onstate-solo")
  -- (the restricted environment's frame handle: Show allowed on a protected frame in combat)
  local function Handle(f) return { IsShown = function() return f:IsShown() end, IsProtected = function() return f:IsProtected() end, Show = function() f._shown = true end } end
  local handle = { GetFrameRef = function(_, name) return Handle(driver:GetAttribute("frameref-" .. name)) end }
  local fn = assert(loadstring("local self, stateid, newstate = ...\n" .. snippet))
  fn(handle, "solo", state)
end
S.group = nil; S.inCombat = true
local blockedBefore = #M.blocked
CompactPartyFrame._shown = false -- (hidden by the game's own secure code, as the group ends in the fight)
CompactPartyFrame:UpdateVisibility(); Run()
check(not CompactPartyFrame:IsShown(), "left the group in combat: not shown by the addon's own code (protected then)")
Resolve()
check(CompactPartyFrame:IsShown(), "the game's state driver shows it at once, in combat")
local mine = 0
for i = blockedBefore + 1, #M.blocked do if M.blocked[i]:find("CompactPartyFrame") then mine = mine + 1 end end
check(mine == 0, "nothing of the addon's refused by the game in the fight")
CompactPartyFrame._shown = false
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED"); Run()
check(CompactPartyFrame:IsShown(), "out of combat: shown")
-- an invitation declined: the group told gone after the game's update (hidden directly by its raid container)
S.group = "party"; CompactPartyFrame:UpdateVisibility(); Run()
CompactPartyFrame:Hide() -- (the container's unused group frame: Hide, not UpdateVisibility)
S.group = nil
Run()
check(CompactPartyFrame:IsShown(), "hidden directly, the group gone a moment later: shown again")

out("")
out(fails .. " failure(s)")
