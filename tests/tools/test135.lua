-- Group quest progress (Modules/GroupQuests): the player's quest log sent to the group (whole, then only what
-- changed, a quest gone said so), the members' logs heard, and their progress written in the tooltip of an item,
-- a creature or an object of their quest: after the other addons' lines, not when Questie or the game already
-- shows that member, nothing for players, secret data or a name only part of an item's
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70959", "Nov 17 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }
-- (WoW Forever's names: a first name and a surname, the whole name "First Surname")
Constants = Constants or {}
Constants.CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " }
UnitNameUnmodified = function(u)
  local x = S.units and S.units[u]
  if x then return x.name, x.surname end
  if u == "player" then return "Rogue" end
end
Enum.TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4 }
Enum.TooltipDataLineType = { QuestObjective = 8, QuestTitle = 17, QuestPlayer = 18 }
RAID_CLASS_COLORS.MAGE = { r = .25, g = .78, b = .92 }
local classes = { player = "ROGUE" }
function UnitClass(u) local c = classes[u] or (S.units and S.units[u] and S.units[u].class) return c, c end
function GetNumSubgroupMembers() local n = 0 for i = 1, 4 do if S.units and S.units["party" .. i] then n = i end end return n end
function GetNumGroupMembers() return GetNumSubgroupMembers() + 1 end

-- the player's quest log
local log = {
  { questID = 2904, title = "A Fine Mess", objs = { { text = "Kernobee rescued", type = "event", numFulfilled = 0, numRequired = 1 } } },
  { questID = 2930, title = "Data Rescue", objs = { { text = "Prismatic Punch Card: 0/1", type = "item", numFulfilled = 0, numRequired = 1 } } },
}
C_QuestLog = C_QuestLog or {}
C_QuestLog.GetNumQuestLogEntries = function() return #log + 1 end
C_QuestLog.GetInfo = function(i)
  if i == 1 then return { questID = 0, isHeader = true, title = "Gnomeregan" } end
  local q = log[i - 1]
  return q and { questID = q.questID, title = q.title, isHeader = false, isHidden = false }
end
C_QuestLog.GetQuestObjectives = function(id)
  for _, q in ipairs(log) do if q.questID == id then return q.objs end end
  return {}
end
C_QuestLog.IsComplete = function(id) return false end

-- the game's tooltip: lines, the post calls in order, then Show (as TooltipDataHandlerMixin:InternalProcessInfo)
local lines, scripts, postCalls = {}, {}, {}
GameTooltip = { }
function GameTooltip:GetName() return "GameTooltip" end
function GameTooltip:NumLines() return #lines end
function GameTooltip:AddLine(t) local fs = { text = t } function fs:GetText() return self.text end lines[#lines + 1] = fs; _G["GameTooltipTextLeft" .. #lines] = fs end
function GameTooltip:ClearLines() lines = {} if scripts.OnTooltipCleared then scripts.OnTooltipCleared(self) end end
local shows = 0
function GameTooltip:Show() shows = shows + 1 end
function GameTooltip:HookScript(name, fn) scripts[name] = fn end
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = { kind, fn } end }
local function Build(data)
  GameTooltip:ClearLines()
  for _, l in ipairs(data.lines) do GameTooltip:AddLine(l.leftText) end
  for _, pc in ipairs(postCalls) do if pc[1] == data.type then pc[2](GameTooltip, data) end end
  GameTooltip:Show()
  local t = {}
  for i, fs in ipairs(lines) do t[i] = fs.text end
  return t
end
local function Has(t, pattern) for _, l in ipairs(t) do if type(l) == "string" and l:find(pattern) then return l end end end
local function Count(t) return #t end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local G = ns.GroupQuests
check(G ~= nil, "the module runs (WoW Forever)")
if not G then out(fails .. " FAILED") return end

local function Drain() for _ = 1, 40 do M.Frame(0.5) end end
local function Sent() local t = {} for _, m in ipairs(M.addonSent) do if m[1] == "ClaraQuests" then t[#t + 1] = m end end return t end
local function Timers() while M.timers and M.timers[1] do M.RunTimer() end end

out("== names, counts out of an objective's text")
check(G.Bare("Robo-mechanical Guts: 3/24") == "Robo-mechanical Guts", "\"Thing: 3/24\"")
check(G.Bare("3/24 Robo-mechanical Guts") == "Robo-mechanical Guts", "\"3/24 Thing\"")
check(G.Bare("Tripes robo-mécaniques : 3/24") == "Tripes robo-mécaniques", "French \"Chose : 3/24\"")
check(G.Short("Lia Moon-Living Flame") == "Lia Moon" and G.Short("Lia Moon") == "Lia Moon", "a member by first name and surname, the realm left out")
check(G.Named("Leper Gnome slain", "Leper Gnome") and G.Named("Lépreux gnome tué", "Lépreux gnome") and not G.Named("Defias Bandit Leader slain", "Defias Bandit")
  and not G.Named("Leper Gnome slain", "Gnome"), "a creature's objective: its name and one word, not a longer name")
check(G.Holds("Leper Gnome slain", "Leper Gnome") and not G.Holds("Leper Gnomes slain", "Leper Gnome") and not G.Holds("Gnomeregan", "Gnome"),
  "a creature's name held whole only")

out("== alone: nothing sent")
G.Update(true)
Drain()
check(#Sent() == 0, "not in a group: no message")

out("== joining a group: asked for theirs, ours sent whole")
S.group = "party"
S.units = { party1 = { name = "Lia", surname = "Moon", guid = "Player-1-0001", player = true, class = "MAGE" } }
M.Fire("GROUP_ROSTER_UPDATE")
Timers(); Drain(); Timers(); Drain()
local sent = Sent()
check(#sent >= 2 and sent[1][2] == "H" and sent[1][3] == "PARTY", "\"H\" first, to the party")
local whole = sent[2] and sent[2][2] or ""
check(whole:find("^F~") and whole:find("Q%^2904%^0%^A Fine Mess%^0,1,e,Kernobee rescued") and whole:find("Q%^2930%^0%^Data Rescue%^0,1,i,Prismatic Punch Card"),
  "then the whole log: " .. whole)
local long = true
for _, m in ipairs(sent) do if #m[2] > 255 then long = false end end
check(long, "every message under the game's 255")

out("== a count changing: only that quest; a quest gone: said so")
M.addonSent = {}
log[2].objs[1].numFulfilled = 1
M.Fire("QUEST_LOG_UPDATE"); Timers(); Drain()
sent = Sent()
check(#sent == 1 and sent[1][2] == "Q^2930^0^Data Rescue^1,1,i,Prismatic Punch Card", "the changed quest alone: " .. tostring(sent[1] and sent[1][2]))
M.addonSent = {}
table.remove(log, 1)
M.Fire("QUEST_REMOVED", 2904); Timers(); Drain()
sent = Sent()
check(#sent == 1 and sent[1][2] == "X^2904", "the quest gone: " .. tostring(sent[1] and sent[1][2]))

out("== many quests: several messages, each whole records")
M.addonSent = {}
for i = 1, 20 do
  table.insert(log, { questID = 3000 + i, title = "A quest with a rather long title number " .. i,
    objs = { { text = "Some creature with a long name slain: 1/10", type = "monster", numFulfilled = 1, numRequired = 10 },
             { text = "Some item with a long name: 2/8", type = "item", numFulfilled = 2, numRequired = 8 } } })
end
G.Update(true); Drain()
sent = Sent()
local ok, recs = true, 0
for _, m in ipairs(sent) do
  if #m[2] > 255 then ok = false end
  for r in (m[2] .. "~"):gmatch("(.-)~") do if r:find("^Q%^") then recs = recs + 1 end end
end
check(#sent > 1 and ok and recs == 21, #sent .. " messages, all under 255, the 21 quests in them")
for _ = 1, 20 do table.remove(log) end

out("== heard from a member")
M.Fire("CHAT_MSG_ADDON", "ClaraQuests", "F~Q^2930^0^Data Rescue^0,1,i,Prismatic Punch Card~Q^2945^0^Gyrodrillmatic Excavationators^12,24,i,Robo-mechanical Guts",
  "PARTY", "Lia Moon-Living Flame")
M.Fire("CHAT_MSG_ADDON", "ClaraQuests", "Q^2924^0^Essential Artificials^3,12,i,Essential Artificial~Q^2928^0^Gyrodrillmatic^4,10,m,Leper Gnome slain~Q^2929^0^The Grand Betrayal^0,1,m,Mekgineer Thermaplugg slain",
  "PARTY", "Lia Moon-Living Flame")
local lia = G.members["lia moon"]
check(lia and lia.quests[2945] and lia.quests[2945][3][1][1] == 12 and lia.quests[2945][3][1][2] == 24 and lia.quests[2928],
  "Lia Moon's quests kept, by her whole name")
M.Fire("CHAT_MSG_ADDON", "ClaraQuests", "Q^1^0^x^1,2,i,y", "WHISPER", "Lia Moon-Living Flame")
M.Fire("CHAT_MSG_ADDON", "ClaraQuests", "Q^1^0^x^1,2,i,y", "PARTY", M.Secret("Lia Moon"))
check(not lia.quests[1], "a whisper, a secret sender: not taken")

out("== the item's tooltip")
local t = Build({ type = 0, lines = { { leftText = "Robo-mechanical Guts" }, { leftText = "Quest Item" } } })
local line = Has(t, "Lia Moon")
check(line and line:find("|cff3fc6e[ab]Lia Moon|r") and line:find("12/24|r Robo%-mechanical Guts"), "Lia Moon: 12/24 Robo-mechanical Guts, her name in her class color: " .. tostring(line))
check(line and line:find("|cff"), "the count colored")
t = Build({ type = 0, lines = { { leftText = "Robo-mechanical Guts" } } })
check(Count(t) == 2, "built again: written once again, not twice")
t = Build({ type = 0, lines = { { leftText = "Mechanical Guts" } } })
check(not Has(t, "Lia Moon"), "an item whose name is only part of the objective's: nothing")
t = Build({ type = 0, lines = { { leftText = "Linen Cloth" } } })
check(not Has(t, "Lia Moon"), "an item that is no member's: nothing")

out("== Questie writing her progress first: not twice")
TooltipDataProcessor.AddTooltipPostCall(0, function(tip, data)
  if data.lines[1].leftText == "Robo-mechanical Guts" then tip:AddLine("   24/24 Robo-mechanical Guts (|cff3fc6ebLia Moon|r|cffffffff)|r") end
end)
t = Build({ type = 0, lines = { { leftText = "Robo-mechanical Guts" } } })
local n = 0
for _, l in ipairs(t) do if type(l) == "string" and l:find("Lia Moon") then n = n + 1 end end
check(n == 1 and t[#t]:find("%(|cff3fc6ebLia Moon"), "her line from Questie only (Clara's run before it, writes after it)")
postCalls[#postCalls] = nil

out("== a creature's tooltip")
t = Build({ type = 2, guid = "Creature-0-1-2-3-6206-0000", lines = { { leftText = "Leper Gnome" }, { leftText = "Level 25" } } })
line = Has(t, "Lia Moon")
check(line and line:find("4/10|r Leper Gnome slain"), "a creature to kill: " .. tostring(line))
t = Build({ type = 2, guid = "Creature-0-1-2-3-7800-0000", lines = { { leftText = "Mekgineer Thermaplugg" } } })
check(Has(t, "Mekgineer Thermaplugg slain"), "a boss without a count: its name alone")
t = Build({ type = 2, guid = "Creature-0-1-2-3-6207-0000", lines = { { leftText = "Gnome" } } })
check(not Has(t, "Lia Moon"), "a creature named only part of another's: nothing")
t = Build({ type = 2, guid = "Player-1-0002", lines = { { leftText = "Leper Gnome" } } })
check(not Has(t, "Lia Moon"), "a player (even named so): nothing")
t = Build({ type = 2, guid = M.Secret("Creature-0"), lines = { { leftText = "Leper Gnome" } } })
check(not Has(t, "Lia Moon"), "secret (a dungeon): nothing, no error")
t = Build({ type = 2, guid = "Creature-0-1-2-3-6206-0000", lines = { { leftText = M.Secret("Leper Gnome") } } })
check(not Has(t, "Lia Moon"), "a secret name: nothing, no error")

out("== the game's own quest lines: a creature dropping the item, a member the game lists itself")
local gnome = { type = 2, guid = "Creature-0-1-2-3-6232-0000", lines = {
  { leftText = "Arcane Nullifier X-21" },
  { type = 17, id = 2945, leftText = "Gyrodrillmatic Excavationators" },
  { type = 8, leftText = "3/24 Robo-mechanical Guts" } } }
t = Build(gnome)
check(Has(t, "Lia Moon.*Robo%-mechanical Guts"), "the creature dropping her item: her count written")
table.insert(gnome.lines, { type = 18, guid = "Player-1-0001", leftText = "Lia Moon" })
table.insert(gnome.lines, { type = 8, leftText = "12/24 Robo-mechanical Guts" })
t = Build(gnome)
local mine = 0
for _, l in ipairs(t) do if type(l) == "string" and l:find("|cff3fc6e[ab]Lia Moon|r") then mine = mine + 1 end end
check(mine == 0, "the game listing her itself: not written again")

out("== an object's tooltip")
M.Fire("CHAT_MSG_ADDON", "ClaraQuests", "Q^2950^0^Toolbox^0,1,o,Gnomish Toolbox searched", "PARTY", "Lia Moon-Living Flame")
t = Build({ type = 4, lines = { { leftText = "Gnomish Toolbox" } } })
check(Has(t, "Lia Moon.*Gnomish Toolbox searched"), "an object to use")

out("== another member asking: our whole log again")
M.addonSent = {}
M.Fire("CHAT_MSG_ADDON", "ClaraQuests", "H", "PARTY", "Lia Moon-Living Flame")
Timers(); Drain()
sent = Sent()
check(sent[1] and sent[1][2]:find("^F~"), "the whole log sent")
M.addonSent = {}
M.Fire("CHAT_MSG_ADDON", "ClaraQuests", "H", "PARTY", "Rogue")
Timers(); Drain()
check(#Sent() == 1 or #Sent() == 0, "our own message heard back: ignored (" .. #Sent() .. ")")

out("== the game refusing for now: sent later, nothing lost")
local refuse = 2
C_ChatInfo.SendAddonMessage = function(prefix, text, chatType, target)
  if refuse > 0 then refuse = refuse - 1 return 11 end
  table.insert(M.addonSent, { prefix, text, chatType, target }) return 0
end
M.addonSent = {}
log[1].objs[1].numFulfilled = 0
M.Fire("QUEST_LOG_UPDATE"); Timers()
M.Frame(0.1); M.Frame(0.1)
check(#Sent() == 0 and #G.queue == 1, "locked: kept")
Drain()
check(#Sent() == 1 and #G.queue == 0, "sent once the game allows it")

out("== a member leaving: forgotten; the group left: all forgotten")
S.units = { party1 = { name = "Saintanger", surname = "Belle", guid = "Player-1-0003", player = true, class = "PRIEST" } }
M.Fire("GROUP_ROSTER_UPDATE")
check(G.members["lia moon"] == nil, "Lia Moon gone from the group: her quests forgotten")
t = Build({ type = 0, lines = { { leftText = "Robo-mechanical Guts" } } })
check(not Has(t, "Lia Moon"), "her line no more")
M.Fire("CHAT_MSG_ADDON", "ClaraQuests", "Q^2930^0^Data Rescue^0,1,i,Prismatic Punch Card", "PARTY", "Saintanger Belle-Living Flame")
S.group = nil; S.units = {}
M.Fire("GROUP_ROSTER_UPDATE")
check(next(G.members) == nil, "out of the group: nothing kept")

out("== /cl quetes")
local printed = {}
local oldPrint = print
print = function(s) printed[#printed + 1] = s end
G.Report()
S.group = "party"; S.units = { party1 = { name = "Lia", surname = "Moon", guid = "Player-1-0001", player = true, class = "MAGE" } }
M.Fire("CHAT_MSG_ADDON", "ClaraQuests", "F~Q^2930^0^Data Rescue^0,1,i,Prismatic Punch Card", "PARTY", "Lia Moon-Living Flame")
G.Report()
print = oldPrint
check(printed[1] and printed[1]:find("not in a group"), "alone: said so")
check(printed[2] and printed[2]:find("Lia Moon: 1 quests heard"), "a member: what was heard: " .. tostring(printed[2]))
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
