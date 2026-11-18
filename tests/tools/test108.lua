-- Clara: Share Quest played as the game plays its macro (cut at 255 characters), three times in a row
-- The classic quest log (Modules/QuestLog): ClassicUI Forever's 1.x quest log as a module of Clara's own, opened by the
-- quest log key (override bindings, set out of combat) and an unseen button over the quest log micro button; its rows
-- (headers the game folded opened, folded in our list instead), its page and rewards, the All tab, watching with shift,
-- the quest levels (the game's setting), the double pane (its radio and its card's box), abandon, a quest giver's
-- window closing it, Escape, its place kept; Share's secure pad (armed out of combat, away in combat)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
do local f = io.open(ADDON_DIR .. "/Modules/QuestLog/QuestLogWindow.lua", "rb")
  if not f then out("  ok   not in this version (Clara's own quest log: the sans version only (avec: ClassicUI's))"); out("0 failure(s)"); return 0 end
  f:close() end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
-- (every other module off: only this one runs)
ClaraComboPointsDB = { qol = { nodesight = false, classicui = false, doesitdie = false, whatstraining = false,
  enhancedraidframes = false, names = false, lfgforever = false, buyemall = false, leatrix = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, tullarange = false, tooltipanchor = false,
  money = false, prices = false, sniper = false, whocooldown = false, idtip = false, soloraidframe = false,
  enemycasts = false, fishing = false, unitscan = false, reverseengineering = false, xptext = false } }

-- The game: its quest log (Elwynn open; Westfall folded by the game), the quest API, bindings, the micro button
local LOG = {
  { title = "Elwynn Forest", isHeader = true, headerSortKey = "elwynn" },
  { title = "Wolves Across the Border", questID = 100, level = 2, difficultyLevel = 2 },
  { title = "Kobold Camp Cleanup", questID = 101, level = 4, difficultyLevel = 4 },
  { title = "Westfall", isHeader = true, headerSortKey = "westfall", isCollapsed = true },
  { title = "The Defias Brotherhood", questID = 102, level = 14, difficultyLevel = 14 },
}
local expanded = {}
local function Visible()
  local list, skip = {}, false
  for _, e in ipairs(LOG) do
    if e.isHeader then skip = e.isCollapsed; list[#list + 1] = e elseif not skip then list[#list + 1] = e end
  end
  return list
end
function ExpandQuestHeader(i)
  local e = Visible()[i]
  if e and e.isHeader then e.isCollapsed = false; expanded[#expanded + 1] = e.title end
end
local selected, watched, complete = 0, {}, { [101] = true }
local abandonSet
C_QuestLog = {
  GetNumQuestLogEntries = function()
    local n = 0
    for _, e in ipairs(LOG) do if not e.isHeader then n = n + 1 end end
    return #Visible(), n
  end,
  GetInfo = function(i)
    local e = Visible()[i]
    if not e then return nil end
    local copy = {}
    for k, v in pairs(e) do copy[k] = v end
    copy.questLogIndex = i
    return copy
  end,
  GetSelectedQuest = function() return selected end,
  SetSelectedQuest = function(id) selected = id end,
  IsComplete = function(id) return complete[id] == true end,
  IsFailed = function() return false end,
  GetQuestWatchType = function(id) return watched[id] end,
  AddQuestWatch = function(id) watched[id] = 0 end,
  RemoveQuestWatch = function(id) watched[id] = nil end,
  IsPushableQuest = function(id) return id ~= 102 end,
  GetMaxNumQuestsCanAccept = function() return 20 end,
  GetQuestTagInfo = function() return nil end,
  SetAbandonQuest = function() abandonSet = selected end,
  GetAbandonQuestName = function()
    for _, e in ipairs(LOG) do if e.questID == selected then return e.title end end
  end,
  GetAbandonQuestItems = function() return {} end,
  IsUnitOnQuest = function(unit, id) return unit == "party1" and id == 100 end,
  GetRequiredMoney = function() return 0 end,
}
local TEXT = { [100] = { "Wolves have been seen across the border.", "Kill 8 Prowlers." },
  [101] = { "Kobolds infest the camp.", "Kill 10 Kobold Vermin." }, [102] = { "Find the Defias.", "Report to Gryan." } }
local function IndexQuest(index) local e = Visible()[index] return e and e.questID end
function GetQuestLogQuestText(index) local t = TEXT[IndexQuest(index)] or {} return t[1], t[2] end
function GetNumQuestLeaderBoards(index) return IndexQuest(index) and 1 or 0 end
function GetQuestLogLeaderBoard(i, index)
  local id = IndexQuest(index)
  if id == 101 then return "Kobold Vermin slain: 10/10", "monster", true end
  return "Prowler slain: 3/8", "monster", false
end
function GetQuestLogTimeLeft() return nil end
function GetNumQuestLogChoices(id) return id == 100 and 2 or 0 end
function GetNumQuestLogRewards(id) return id == 100 and 1 or 0 end
function GetQuestLogRewardMoney(id) return id == 100 and 125 or 0 end
function GetQuestLogRewardXP(id) return id == 100 and 450 or 0 end
function GetQuestLogChoiceInfo(i) return ({ "Worn Leather Gloves", "Worn Mail Gloves" })[i], 132952, 1, 1, true, 2000 + i end
function GetQuestLogRewardInfo(i) return "Minor Healing Potion", 134829, 3, 1, true, 118 end
function GetQuestLink(id) return "|Hquest:" .. id .. "|h[quest]|h" end
function SecondsToTime(s) return s .. " sec" end
function BreakUpLargeNumbers(n) return tostring(n) end
function IsModifiedClick() return false end
function IsModifierKeyDown() return M.shift == true end
function GetNumSubgroupMembers() return S.group == "party" and 1 or 0 end
local cvars = { showQuestLevel = "0" }
function GetCVarBool(name) return cvars[name] == "1" end
function issecurevariable() return true end
UIErrorsFrame = { messages = {} }
function UIErrorsFrame:AddMessage(text) table.insert(self.messages, text) end
ERR_NOT_IN_COMBAT = "You can't do that while in combat"
StaticPopupDialogs.ABANDON_QUEST = { text = "Abandon \"%s\"?", button1 = "Yes", button2 = "No" }
StaticPopupDialogs.ABANDON_QUEST_WITH_ITEMS = { text = "Abandon \"%s\"? %s", button1 = "Yes", button2 = "No" }
-- the override bindings set (key -> button name), and how many times
local overrides, overrideSets = {}, 0
function SetOverrideBindingClick(owner, priority, key, name)
  assert(not S.inCombat, "override binding in combat")
  overrides[key] = name
  overrideSets = overrideSets + 1
end
function ClearOverrideBindings() assert(not S.inCombat, "override binding in combat") overrides = {} end
S.bindings = { TOGGLEQUESTLOG = "L" }
-- the micro button (bottom right), the minimap's zone text (the map's own button), the map
QuestLogMicroButton = CreateFrame("Button", "QuestLogMicroButton", UIParent)
QuestLogMicroButton:SetSize(24, 32)
QuestLogMicroButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 900, 4)
QuestLogMicroButton.tooltipText = "Quest Log (L)"
local microClicks = 0
QuestLogMicroButton:SetScript("OnClick", function() microClicks = microClicks + 1 end)
MinimapCluster = CreateFrame("Frame", "MinimapCluster", UIParent)
MinimapCluster.ZoneTextButton = CreateFrame("Button", nil, MinimapCluster)
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent); WorldMapFrame:Hide()
QuestMapFrame = CreateFrame("Frame", "QuestMapFrame", WorldMapFrame)
EditModeManagerFrame = CreateFrame("Frame", "EditModeManagerFrame", UIParent); EditModeManagerFrame:Hide()

S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
local Q = ns.QuestLogPrivate
local function F() return _G.ClaraQuestLogFrame end
local function Plain(t) return ((t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function Rows() return F().rows end
local function RowTexts()
  local list = {}
  for _, row in ipairs(Rows()) do
    if row:IsShown() and row.text then list[#list + 1] = Plain(row.text._text) end
  end
  return list
end

local chain = dofile(TOOLS_DIR .. "/qlshare_chain.lua")
out("== Share Quest, three times in a row: the map shut each time")
chain(M, S, check, ns, Q, F)
out(string.format("\n%d failure(s)", fails))
return fails
