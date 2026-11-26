-- A quest from the chat (QuestShare.lua): the "Quest accepted" line's quest a link (the bubble after it with the box
-- ticked, off by default); over it, out of combat, the secure pad under the mouse; a double middle click on the name,
-- or a left click on the bubble, opens the map on that quest (the game's row of it pressed: its details) and, in a
-- group, presses the game's Share; the map left open on the quest (no Back, no closing); the map already open: not
-- opened again; the row not there yet: said; a single middle click nothing; in a fight nothing, and why said; the pad
-- away as a fight begins; a line that names no quest of the log left as it is.
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
-- the map's quest pane, its row of the quest and its details' Share (the game's)
QuestMapFrame.DetailsFrame = CreateFrame("Frame", nil, QuestMapFrame)
QuestMapFrame.DetailsFrame.ShareButton = CreateFrame("Button", nil, QuestMapFrame.DetailsFrame)
local row = CreateFrame("Button", nil, QuestMapFrame)
row.questID = 1105
local rowThere = true
function QuestLogQuests_GetQuestButton(id) if rowThere and id == row.questID then return row end end
function issecurevariable() return true end
local aimed
local function Click(button)
  pad:GetScript("PreClick")(pad, button)
  local m = pad:GetAttribute("macrotext")
  aimed = {}
  if m ~= "" then
    -- (the macro's /click steps: each one aimed as it runs; the first opens the map)
    for i = 1, 20 do
      local step = _G["ClaraQuestShareStep" .. i]
      if not step then break end
      local pre = step:GetScript("PreClick")
      if pre then pre(step, "LeftButton") end
      aimed[i] = step:GetAttribute("clickbutton")
      if i == 1 and aimed[1] then WorldMapFrame:Show(); QuestMapFrame:Show() end
    end
  end
  pad:GetScript("PostClick")(pad, button)
  WorldMapFrame:Hide()
  return m
end
check(Click("MiddleButton") == "", "a single middle click: nothing")
now = now + 0.2
local m = Click("MiddleButton")
check(m and m:find("/click [nomod] ClaraQuestShareStep1", 1, true) and m:find("/click ClaraQuestShareStep8", 1, true)
  and not m:find("Step9", 1, true), "a double middle click: the macro, eight steps (no Back, no closing)")
check(aimed[1] == MinimapCluster.ZoneTextButton and aimed[7] == row and aimed[8] == QuestMapFrame.DetailsFrame.ShareButton,
  "the map opened, the quest's row pressed (its details), the game's Share pressed")
now = now + 2
check(Click("LeftButton") == "", "a left click on the name: nothing")
enter(ChatFrame1, "addon:ClaraComboPoints:qshare:share:1106")
check((Click("LeftButton") or ""):find("ClaraQuestShareStep", 1, true), "a left click on the bubble: shared")

out("== out of a group, the map open, the row not there")
enter(ChatFrame1, "addon:ClaraComboPoints:qshare:quest:1105")
grouped = false
now = now + 2; Click("MiddleButton"); now = now + 0.2
m = Click("MiddleButton")
check(m ~= "" and aimed[7] == row and aimed[8] == nil, "out of a group: its details shown, no Share")
grouped = true
WorldMapFrame:Show(); QuestMapFrame:Show()
local opened = 0
MinimapCluster.ZoneTextButton:SetScript("OnClick", function() opened = opened + 1 end)
now = now + 2; pad:GetScript("PreClick")(pad, "MiddleButton"); pad:GetScript("PostClick")(pad, "MiddleButton"); now = now + 0.2
pad:GetScript("PreClick")(pad, "MiddleButton")
local step1 = _G.ClaraQuestShareStep1
check(pad:GetAttribute("macrotext") ~= "" and step1:GetAttribute("clickbutton") == nil, "the map already open: not opened again (nothing said)")
pad:GetScript("PostClick")(pad, "MiddleButton")
WorldMapFrame:Hide()
rowThere = false
now = now + 2; Click("MiddleButton"); now = now + 0.2
local before = #said
m = Click("MiddleButton")
check(#said == before + 1 and said[#said]:find("double middle click", 1, true), "the row not there yet: said (" .. tostring(said[#said]) .. ")")
check(ns:QuestShareReport():find("no row", 1, true), "the report says why: " .. ns:QuestShareReport())
rowThere = true
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
