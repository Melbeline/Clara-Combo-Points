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
-- Never shown nor placed by the addon's own code (its frames' updates would run in its name, failing on secret
-- health): the addon arms a secure handler; the game's driver manager sets its state at each of its passes (secure),
-- and the handler's restricted code, solo, shows the frame if hidden and places it if it has no point (the game
-- places it only while it is shown: hidden through every layout since the login, it had none, not drawn though shown)
local addonShows, addonPoints = 0, 0
local realShow, realSetPoint = CompactPartyFrame.Show, CompactPartyFrame.SetPoint
CompactPartyFrame.Show = function(self, ...) addonShows = addonShows + 1 return realShow(self, ...) end
CompactPartyFrame.SetPoint = function(self, ...) addonPoints = addonPoints + 1 return realSetPoint(self, ...) end
local D = ns.SoloRaidFrameDriver
local arm = D and M.stateDrivers[D]
check(D ~= nil and arm and arm[1] == "arm" and arm[2] == "go", "a secure handler of its own, its state driven by the game (" .. tostring(arm and arm[2]) .. ")")
check(D and D:GetAttribute("armed") == true and D:GetAttribute("state-arm") == "wait", "armed, its state set back by hand")
check(M.stateDrivers[CompactPartyFrame] == nil, "no driver put on the frame")
check(D and D:GetAttribute("x") == 2, "the game's left margin for it: 2 (" .. tostring(D and D:GetAttribute("x")) .. ")")
-- the restricted environment: only what the game gives a snippet (anything else an error)
local function Points(f) return #(rawget(f, "_points") or {}) end
local RESTRICTED = { PlayerInCombat = function() return S.inCombat == true end,
  SecureCmdOptionParse = function(rule)
    local a, b = rule:match("^%[group%] (%S+); (%S+)$")
    return IsInGroup() and a or b
  end }
local function Snippet(newstate)
  local handle = { GetAttribute = function(_, k) return D:GetAttribute(k) end, SetAttribute = function(_, k, v) D:SetAttribute(k, v) end,
    GetFrameRef = function(_, name)
      local f = D:GetAttribute("frameref-" .. name)
      -- the handle on the frame: reaches an unprotected frame only out of combat; shows and places it from secure code
      local function Reach() if S.inCombat and not f._protected then error("Invalid frame handle") end return f end
      return f and { IsProtected = function() return f._protected == true end,
        IsShown = function() return Reach()._shown ~= false end, Show = function() Reach()._shown = true end,
        GetNumPoints = function() return Points(Reach()) end,
        SetPoint = function(_, p, rel, rp, x, y) assert(rel == "$parent") Reach()._points = { { p, f._parent, rp, x, y } } end }
    end }
  local env = setmetatable({ self = handle, newstate = newstate }, { __index = function(_, k)
    if RESTRICTED[k] then return RESTRICTED[k] end
    error("not in the restricted environment: " .. tostring(k))
  end })
  local fn = assert(loadstring(D:GetAttribute("_onstate-arm")))
  setfenv(fn, env)
  fn()
end
-- the game's manager at each pass: "go", not the value it holds: set, by the game
local function Tick()
  if D:GetAttribute("state-arm") ~= arm[2] then D:SetAttribute("state-arm", arm[2]) Snippet(arm[2]) end
end
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 100 do M.RunTimer() n = n + 1 end end
S.group = nil
CompactPartyFrame._points = {} -- (just made by the game: no point)
CompactPartyFrame:UpdateVisibility(); Run()
check(not CompactPartyFrame:IsShown(), "before the game's pass: hidden still (nothing done by the addon's code)")
Tick()
check(CompactPartyFrame:IsShown(), "solo: the raid-style party frame shown (the game had hidden it)")
local p = CompactPartyFrame._points[1]
check(Points(CompactPartyFrame) == 1 and p[1] == "TOPLEFT" and p[2] == UIParent and p[3] == "TOPLEFT" and p[4] == 2 and p[5] == 0,
  "never placed by the game: put at its parent's top left, where the game's layout puts it (" .. tostring(p and p[1]) .. " " .. tostring(p and p[4]) .. ")")
check(D:GetAttribute("reshown") == 1 and D:GetAttribute("placed") == 1, "counted: shown again 1, placed 1")
check(D:GetAttribute("state-arm") == "wait", "its state set back by its secure code: looked at again at the manager's next pass")
Tick()
check(D:GetAttribute("reshown") == 1 and D:GetAttribute("placed") == 1, "shown and placed already: left alone")
-- the game lays it out itself while it is shown, then hides it (its visibility update, a login, an option changed)
CompactPartyFrame._points = { { "TOPLEFT", UIParent, "TOPLEFT", 6, 0 } }
CompactPartyFrame:UpdateVisibility(); Run()
check(not CompactPartyFrame:IsShown(), "hidden by the game's visibility update")
Tick()
check(CompactPartyFrame:IsShown() and D:GetAttribute("reshown") == 2, "shown again at the next pass")
check(CompactPartyFrame._points[1][4] == 6 and D:GetAttribute("placed") == 1, "the game's own place kept")
local report = ns.SoloRaidFrameReport and ns:SoloRaidFrameReport()
check(report and report:find("handler made", 1, true) and report:find("shown again 2 times, placed 1 times", 1, true), "/cl souris's line: " .. tostring(report))
S.group = "party"
CompactPartyFrame:UpdateVisibility(); Run(); Tick()
check(CompactPartyFrame:IsShown(), "in a group: the game's rule")
CompactPartyFrame._shown = false; Tick()
check(not CompactPartyFrame:IsShown(), "in a group, the game hiding it (its own party frames chosen): left hidden")
S.group = nil; S.inCombat = true
local blockedBefore = #M.blocked
CompactPartyFrame._shown = false -- (hidden by the game's own secure code, as the group ends in the fight)
CompactPartyFrame:UpdateVisibility(); Run()
local ok, e = pcall(Tick)
check(ok and CompactPartyFrame:IsShown(), "left the group in combat: shown again at the next pass (" .. tostring(e) .. ")")
local mine = 0
for i = blockedBefore + 1, #M.blocked do if M.blocked[i]:find("CompactPartyFrame") then mine = mine + 1 end end
check(mine == 0, "nothing of the addon's refused by the game in the fight")
CompactPartyFrame._protected = false; CompactPartyFrame._shown = false
ok, e = pcall(Tick)
check(ok and not CompactPartyFrame:IsShown(), "in combat, a frame not protected (out of reach then): left alone, no error (" .. tostring(e) .. ")")
CompactPartyFrame._protected = true
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED"); Run(); Tick()
check(CompactPartyFrame:IsShown(), "the fight over: shown")
S.group = "party"; CompactPartyFrame:UpdateVisibility(); Run()
CompactPartyFrame._shown = false -- (the container's unused group frame hidden: Hide, not UpdateVisibility)
S.group = nil
M.Fire("GROUP_ROSTER_UPDATE"); Run(); Tick()
check(CompactPartyFrame:IsShown(), "hidden directly, the group gone a moment later: shown again")
check(addonShows == 0 and addonPoints == 0, "never shown nor placed by the addon's own code (" .. addonShows .. ", " .. addonPoints .. ")")

out("")
out(fails .. " failure(s)")
