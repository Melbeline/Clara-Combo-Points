-- ClassicQuestLog in the game's own UI code: opened by its key's button (the double pane by default), a quest picked,
-- one pane and back, its grip, its options page, closed; no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local LOG = {
  { title = "Darkshore", isHeader = true },
  { title = "Onu", questID = 100, level = 17, difficultyLevel = 17 },
  { title = "Holy Diver", questID = 101, level = 20, difficultyLevel = 20 },
}
local selected = 0
local C = env.C_QuestLog
C.GetNumQuestLogEntries = function() return #LOG, 2 end
C.GetInfo = function(i) local e = LOG[i] if not e then return nil end local c = { questLogIndex = i } for k, v in pairs(e) do c[k] = v end return c end
C.GetSelectedQuest = function() return selected end
C.SetSelectedQuest = function(id) selected = id end
C.IsComplete = function(id) return id == 101 end
C.IsFailed = function() return false end
C.GetQuestWatchType = function() return nil end
C.IsPushableQuest = function() return true end
C.GetMaxNumQuestsCanAccept = function() return 40 end
C.GetQuestTagInfo = function() return nil end
C.GetRequiredMoney = function() return 0 end
C.IsUnitOnQuest = function() return false end
env.GetQuestLogQuestText = function() return "A description.", "The objectives." end
env.GetNumQuestLeaderBoards = function() return 1 end
env.GetQuestLogLeaderBoard = function() return "Thresher slain: 3/8", "monster", false end
env.GetQuestLogTimeLeft = function() return nil end
env.GetNumQuestLogChoices = function() return 0 end
env.GetNumQuestLogRewards = function() return 2 end
env.GetQuestLogRewardMoney = function() return 12 end
env.GetQuestLogRewardXP = function() return 1550 end
env.GetQuestLogRewardInfo = function(i) return ({ "Draught of Water Breathing", "Swim Speed Potion" })[i], 134754, 5, 1, true, 5996 end
local function Press(b) local fn = b:GetScript("OnClick") return fn(b, "LeftButton", false) end
local toggle = rawget(env, "ClassicQuestLogToggle")
check(toggle ~= nil and not ns.off, "running, its key's button made")
-- (the harness ran every slash command first, /cql among them: the log may be open)
local open = ns.QL.Frame()
if open and open:IsShown() then open:Hide() end
local ok, e = pcall(Press, toggle)
H.RunTimers()
local frame = ns.QL.Frame()
check(ok and frame and frame:IsShown(), "opened" .. (ok and "" or (": " .. tostring(e))))
check(frame and frame.dual == true, "in the double pane by default")
ok, e = pcall(function() Press(frame.rows[3]) end)
check(ok and selected == 101, "a quest picked" .. (ok and "" or (": " .. tostring(e))))
ok, e = pcall(function() ns.SetDual(false) ns.SetDual(true) end)
check(ok and frame.dual == true, "one pane and back" .. (ok and "" or (": " .. tostring(e))))
ok, e = pcall(function()
  local grip = frame.grip
  grip:GetScript("OnMouseDown")(grip, "LeftButton")
  grip:GetScript("OnUpdate")(grip, 0.02)
  grip:GetScript("OnMouseUp")(grip, "LeftButton")
  grip:GetScript("OnClick")(grip, "RightButton")
end)
check(ok, "its grip" .. (ok and "" or (": " .. tostring(e))))
ok, e = pcall(function() ns.optionsPage:GetScript("OnShow")(ns.optionsPage) ns.ResetPlace() end)
check(ok, "its options page" .. (ok and "" or (": " .. tostring(e))))
ok, e = pcall(function() Press(frame.exit) end)
check(ok and not frame:IsShown(), "closed")
print("scenario: ClassicQuestLog failures " .. fails)
