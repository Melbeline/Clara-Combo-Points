-- The classic quest log (Modules/QuestLog) in the game's own UI code: opened by its key's button and by the pad over the
-- game's own quest log micro button, a log of two headers and three quests, picked, folded, the double pane, Show Map's
-- and Share's pads on the game's own buttons; no error and nothing protected touched
local H = ...
local env, ns = H.env, H.ns
local Q = ns.QuestLogPrivate
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
if not Q then print("scenario FAIL the quest log module did not load") return end
local LOG = {
  { title = "Elwynn Forest", isHeader = true },
  { title = "Wolves Across the Border", questID = 100, level = 2, difficultyLevel = 2 },
  { title = "Kobold Camp Cleanup", questID = 101, level = 4, difficultyLevel = 4 },
  { title = "Westfall", isHeader = true, isCollapsed = true },
  { title = "The Defias Brotherhood", questID = 102, level = 14, difficultyLevel = 14 },
}
local function Visible()
  local list, skip = {}, false
  for _, e in ipairs(LOG) do
    if e.isHeader then skip = e.isCollapsed; list[#list + 1] = e elseif not skip then list[#list + 1] = e end
  end
  return list
end
local selected = 0
local C = env.C_QuestLog
C.GetNumQuestLogEntries = function() return #Visible(), 3 end
C.GetInfo = function(i)
  local e = Visible()[i]
  if not e then return nil end
  local copy = { questLogIndex = i }
  for k, v in pairs(e) do copy[k] = v end
  return copy
end
C.GetSelectedQuest = function() return selected end
C.SetSelectedQuest = function(id) selected = id end
C.IsComplete = function(id) return id == 101 end
C.IsFailed = function() return false end
C.GetQuestWatchType = function() return nil end
C.IsPushableQuest = function() return true end
C.GetMaxNumQuestsCanAccept = function() return 20 end
C.GetQuestTagInfo = function() return nil end
C.GetRequiredMoney = function() return 0 end
C.IsUnitOnQuest = function() return false end
env.ExpandQuestHeader = function(i) local e = Visible()[i] if e then e.isCollapsed = false end end
env.GetQuestLogQuestText = function() return "A description.", "The objectives." end
env.GetNumQuestLeaderBoards = function() return 1 end
env.GetQuestLogLeaderBoard = function() return "Prowler slain: 3/8", "monster", false end
env.GetQuestLogTimeLeft = function() return nil end
env.GetNumQuestLogChoices = function() return 2 end
env.GetNumQuestLogRewards = function() return 1 end
env.GetQuestLogRewardMoney = function() return 125 end
env.GetQuestLogRewardXP = function() return 450 end
env.GetQuestLogChoiceInfo = function(i) return "Gloves " .. i, 132952, 1, 1, true, 2000 + i end
env.GetQuestLogRewardInfo = function() return "Minor Healing Potion", 134829, 3, 1, true, 118 end

local function Press(b) local fn = b:GetScript("OnClick") return fn(b, "LeftButton", false) end
local toggle = rawget(env, "ClaraQuestLogToggle")
check(toggle ~= nil, "the key's button made")
local ok, e = pcall(function() Press(toggle) end)
H.RunTimers()
check(ok, "opened by the key's button" .. (ok and "" or (": " .. tostring(e))))
local frame = Q.QL.Frame()
check(frame and rawget(env, "ClaraQuestLogFrame") == frame or env.ClaraQuestLogFrame == frame, "named (Escape: UISpecialFrames)")
check(frame and frame:IsShown(), "the window shown")
if not frame then print("scenario: quest log failures " .. fails) return end
local texts = {}
for _, row in ipairs(frame.rows) do if row:IsShown() then texts[#texts + 1] = row.text:GetText() end end
check(#texts == 5, "five rows (" .. table.concat(texts, " | ") .. ")")
check(selected == 100, "the first quest picked")
ok, e = pcall(function() Press(frame.rows[3]) end)
check(ok and selected == 101, "a quest picked by its row" .. (ok and "" or (": " .. tostring(e))))
ok, e = pcall(function() Press(frame.rows[1]) end)
check(ok, "a header folded" .. (ok and "" or (": " .. tostring(e))))
local sw = ns.qolSwitches.questlog[1]
ok, e = pcall(sw.set, true)
check(ok and frame.dual == true, "the double pane" .. (ok and "" or (": " .. tostring(e))))
ok, e = pcall(sw.set, false)
check(ok and frame.dual == false, "one pane again" .. (ok and "" or (": " .. tostring(e))))
ok, e = pcall(function()
  local grip = frame.grip
  grip:GetScript("OnMouseDown")(grip, "LeftButton")
  grip:GetScript("OnUpdate")(grip, 0.02)
  grip:GetScript("OnMouseUp")(grip, "LeftButton")
  grip:GetScript("OnClick")(grip, "RightButton")
end)
check(ok and frame:GetScale() == 1, "the size grip dragged, then its first size" .. (ok and "" or (": " .. tostring(e))))
ok, e = pcall(function() Press(frame.exit) end)
check(ok and not frame:IsShown(), "Exit closes it")
local micro = Q.microPad
check(micro ~= nil, "a pad over the game's quest log micro button")
if micro then
  ok, e = pcall(function() Press(micro) end)
  H.RunTimers()
  check(ok and frame:IsShown(), "its click opens the log" .. (ok and "" or (": " .. tostring(e))))
  ok, e = pcall(function() micro:GetScript("OnEnter")(micro) micro:GetScript("OnLeave")(micro) end)
  check(ok, "its tooltip" .. (ok and "" or (": " .. tostring(e))))
end
check(frame.showMap.pad ~= nil, "Show Map's pad on the game's zone text button")
ok, e = pcall(Q.PlacePads)
check(ok, "the pads placed" .. (ok and "" or (": " .. tostring(e))))
ok, e = pcall(function() frame:Hide() end)
check(ok, "closed")
print("scenario: quest log failures " .. fails)
