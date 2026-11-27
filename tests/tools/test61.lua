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
  self._shown = IsInGroup() and true or false -- (the game's own secure code)
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
-- Never shown by the addon's own code (its frames' updates would run in its name, failing on secret health): the
-- addon arms a secure handler; the game's driver manager sets its state at its next look (secure), and the handler's
-- restricted code registers the frame's own visibility driver, which the game applies (shown solo, its rule in a group)
local addonShows = 0
local realShow = CompactPartyFrame.Show
CompactPartyFrame.Show = function(self, ...) addonShows = addonShows + 1 return realShow(self, ...) end
local D = ns.SoloRaidFrameDriver
local arm = D and M.stateDrivers[D]
check(D ~= nil and arm and arm[1] == "arm" and arm[2] == "go", "a secure handler of its own, its state driven by the game (" .. tostring(arm and arm[2]) .. ")")
check(D and D:GetAttribute("armed") == true and D:GetAttribute("state-arm") == "wait", "armed, its state set back by hand")
check(M.stateDrivers[CompactPartyFrame] == nil, "no driver put on the frame from the addon's code")
-- the restricted environment: the handler's snippet as the game runs it; its RegisterStateDriver applied at once
-- (the manager applies a driver's value only when it changes: solo, "show" once; a frame hidden after that stays so)
local secureRuns, lastValue = 0, nil
local function Visibility()
  local d = M.stateDrivers[CompactPartyFrame]
  if not (d and d[1] == "visibility") then return end
  local value = IsInGroup() and "game" or "show"
  if value == lastValue then return end
  lastValue = value
  if value == "show" then CompactPartyFrame._shown = true elseif value == "hide" then CompactPartyFrame._shown = false end
end
local function Snippet(newstate)
  local handle = { GetAttribute = function(_, k) return D:GetAttribute(k) end, SetAttribute = function(_, k, v) rawset(D, "_attr_" .. k, v) D:SetAttribute(k, v) end,
    GetFrameRef = function(_, name)
      local f = D:GetAttribute("frameref-" .. name)
      -- the restricted code's handle on the protected frame: shown from secure code (not the addon's)
      return f and { _frame = f, IsShown = function() return f._shown == true end, Show = function() f._shown = true end }
    end }
  local env = setmetatable({ self = handle, newstate = newstate,
    SecureCmdOptionParse = function(rule) return (rule:match("^%[group%] (%S+);") and IsInGroup()) and rule:match("^%[group%] (%S+);") or rule:match("; (%S+)$") end,
    RegisterStateDriver = function(frame, state, values) M.stateDrivers[frame._frame or frame] = { state, values } lastValue = nil Visibility() end }, { __index = _G })
  local fn = assert(loadstring(D:GetAttribute("_onstate-arm")))
  setfenv(fn, env)
  fn()
end
-- the game's manager at its next look: "go" again, not "wait": set, by the game
local function Tick()
  secureRuns = secureRuns + 1
  if D:GetAttribute("state-arm") ~= arm[2] then D:SetAttribute("state-arm", arm[2]) Snippet(arm[2]) end
  Visibility()
end
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 100 do M.RunTimer() n = n + 1 end end
S.group = nil
CompactPartyFrame:UpdateVisibility(); Run()
check(not CompactPartyFrame:IsShown(), "before the game's look: hidden still (nothing shown by the addon)")
Tick()
local drive = M.stateDrivers[CompactPartyFrame]
check(drive and drive[1] == "visibility" and drive[2] == "[group] game; show", "the frame's driver registered by the handler's secure code (" .. tostring(drive and drive[2]) .. ")")
check(CompactPartyFrame:IsShown(), "solo: the raid-style party frame shown (the game had hidden it)")
check(D:GetAttribute("state-arm") == "wait", "the handler's state set back by its secure code: looked at again at the manager's next look")
CompactPartyFrame._shown = false -- (hidden again by the game after the driver showed it, as at a login: the driver's value unchanged)
Tick()
check(CompactPartyFrame:IsShown() and (D:GetAttribute("reshown") or 0) >= 1, "solo, hidden again by the game: shown again by the handler's secure code ("
  .. tostring(D:GetAttribute("reshown")) .. ")")
Tick()
check(D:GetAttribute("reshown") == 1, "shown already: left alone (" .. tostring(D:GetAttribute("reshown")) .. ")")
local report = ns.SoloRaidFrameReport and ns:SoloRaidFrameReport()
check(report and report:find("shown again 1 times", 1, true) and report:find("handler made", 1, true), "/cl souris's line: " .. tostring(report))
S.group = "party"
CompactPartyFrame:UpdateVisibility(); Run(); Tick()
check(CompactPartyFrame:IsShown(), "in a group: the game's rule")
CompactPartyFrame._shown = false; Tick()
check(not CompactPartyFrame:IsShown(), "in a group, the game hiding it (its own party frames chosen): left hidden")
S.group = nil; S.inCombat = true
local blockedBefore = #M.blocked
CompactPartyFrame._shown = false -- (hidden by the game's own secure code, as the group ends in the fight)
CompactPartyFrame:UpdateVisibility(); Run(); Tick()
check(CompactPartyFrame:IsShown(), "left the group in combat: shown again by the game's driver")
local mine = 0
for i = blockedBefore + 1, #M.blocked do if M.blocked[i]:find("CompactPartyFrame") then mine = mine + 1 end end
check(mine == 0, "nothing of the addon's refused by the game in the fight")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED"); Run()
S.group = "party"; CompactPartyFrame:UpdateVisibility(); Run()
CompactPartyFrame._shown = false -- (the container's unused group frame hidden: Hide, not UpdateVisibility)
S.group = nil
M.Fire("GROUP_ROSTER_UPDATE"); Run(); Tick()
check(CompactPartyFrame:IsShown(), "hidden directly, the group gone a moment later: shown again")
check(addonShows == 0, "never shown by the addon's own code (" .. addonShows .. ")")

out("")
out(fails .. " failure(s)")
