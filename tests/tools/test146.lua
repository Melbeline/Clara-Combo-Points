-- A quest shared from the chat (QuestShare.lua): the "Quest accepted" line's quest a link (the bubble after it with the
-- box ticked, off by default); over it, out of combat, the secure pad under the mouse; a double middle click on the
-- name, or a left click on the bubble, aims the game's Share at that quest (the macro of /click steps), a single
-- middle click nothing; out of a group, with the map open, or in a fight: nothing, and why said; the pad away as a fight
-- begins; a line that names no quest of the log left as it is.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

ERR_QUEST_ACCEPTED_S = "Quest accepted: %s"
local quests = { { title = "Mirages", questID = 1105 }, { title = "Zone", isHeader = true }, { title = "A Dwarf and His Tools", questID = 1106 } }
C_QuestLog = C_QuestLog or {}
C_QuestLog.GetNumQuestLogEntries = function() return #quests end
C_QuestLog.GetInfo = function(i) return quests[i] end
C_QuestLog.GetTitleForQuestID = function(id) for _, q in ipairs(quests) do if q.questID == id then return q.title end end end
C_QuestLog.GetLogIndexForQuestID = function(id) for i, q in ipairs(quests) do if q.questID == id then return i end end end
local grouped = true
function IsInGroup() return grouped end
WorldMapFrame = WorldMapFrame or CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame:Hide()
QuestMapFrame = QuestMapFrame or CreateFrame("Frame", "QuestMapFrame", UIParent)
MinimapCluster = MinimapCluster or CreateFrame("Frame", "MinimapCluster", UIParent)
MinimapCluster.ZoneTextButton = CreateFrame("Button", "MinimapZoneTextButton", MinimapCluster)
local filters = {}
ChatFrameUtil = ChatFrameUtil or {}
ChatFrameUtil.AddMessageEventFilter = function(event, fn) filters[event] = filters[event] or {}; table.insert(filters[event], fn) end
local said = {}
UIErrorsFrame = { AddMessage = function(_, t) said[#said + 1] = t end }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local now = 100
GetTime = function() return now end

local function Line(msg)
  for _, fn in ipairs(filters.CHAT_MSG_SYSTEM or {}) do
    local stop, new = fn(ChatFrame1, "CHAT_MSG_SYSTEM", msg)
    if stop then return nil end
    if new then msg = new end
  end
  return msg
end

out("== the line")
check(not ns:QuestShareBubble(), "the bubble: off by default")
local line = Line("Quest accepted: Mirages")
check(line == "Quest accepted: |Haddon:ClaraComboPoints:qshare:quest:1105|hMirages|h", "the quest's name a link, nothing else (" .. tostring(line) .. ")")
ns:SetQuestShareBubble(true)
line = Line("Quest accepted: A Dwarf and His Tools")
check(line:find("|hA Dwarf and His Tools|h", 1, true) and line:find("|Haddon:ClaraComboPoints:qshare:share:1106|h|A:UI-QuestPoi-QuestNumber", 1, true),
  "the box ticked: the tracker's bubble after it, a link of its own")
check(Line("Quest accepted: Not In Log") == "Quest accepted: Not In Log", "a quest not in the log: left as it is")
check(Line("You have learned a new spell.") == "You have learned a new spell.", "another line: left as it is")
M.Fire("QUEST_ACCEPTED", 2000)
table.insert(quests, { title = "Fresh", questID = 2000 })
check(Line("Quest accepted: Fresh"):find("quest:2000", 1, true), "a quest just accepted: found")

out("== over it: the pad, and its clicks")
local enter = ChatFrame1:GetScript("OnHyperlinkEnter")
check(enter ~= nil, "the chat window's links watched")
M.cursorX, M.cursorY = 300, 200
enter(ChatFrame1, "addon:ClaraComboPoints:qshare:quest:1105")
local pad = _G.ClaraQuestSharePad
check(pad and pad:IsShown(), "over the quest's name: the pad under the mouse")
local function Click(button)
  pad:GetScript("PreClick")(pad, button)
  local m = pad:GetAttribute("macrotext")
  pad:GetScript("PostClick")(pad, button)
  return m
end
check(Click("MiddleButton") == "", "a single middle click: nothing")
now = now + 0.2
local m = Click("MiddleButton")
check(m and m:find("/click [nomod] ClaraQuestShareStep1", 1, true) and m:find("/click ClaraQuestShareStep8", 1, true), "a double middle click: the game's Share pressed for that quest")
now = now + 2
check(Click("LeftButton") == "", "a left click on the name: nothing")
enter(ChatFrame1, "addon:ClaraComboPoints:qshare:share:1106")
check((Click("LeftButton") or ""):find("ClaraQuestShareStep", 1, true), "a left click on the bubble: shared")

out("== why not")
grouped = false
check(Click("LeftButton") == "" and said[#said]:find("not in a group", 1, true), "out of a group: said")
grouped = true
WorldMapFrame:Show()
check(Click("LeftButton") == "" and said[#said]:find("Close the world map", 1, true), "the map open: said")
WorldMapFrame:Hide()
pad:GetScript("OnLeave")(pad)
check(not pad:IsShown(), "the mouse away: the pad away")
enter(ChatFrame1, "addon:ClaraComboPoints:qshare:quest:1105")
M.Fire("PLAYER_REGEN_DISABLED")
check(not pad:IsShown(), "a fight begins: the pad away")
S.inCombat = true
enter(ChatFrame1, "addon:ClaraComboPoints:qshare:quest:1105")
check(not pad:IsShown(), "in a fight: no pad")
S.inCombat = false
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
