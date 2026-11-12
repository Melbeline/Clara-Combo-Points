-- The quest tracker folded again as the player left it (GameFixes.lua): a click on a fold button kept at once,
-- for each character; folded again as the game adds each section (late at login too) and over the first
-- seconds after a login or reload; a click of the player's ends that; out of combat; the mouse report's lines
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local calls = 0
local function Section(name)
  local f = CreateFrame("Frame", name, UIParent)
  f.isCollapsed = false
  function f:IsCollapsed() return self.isCollapsed end
  function f:SetCollapsed(c) if c then calls = calls + 1 end self.isCollapsed = c end
  f.Header = CreateFrame("Frame", nil, f)
  f.Header.MinimizeButton = CreateFrame("Button", nil, f.Header)
  f.Header.MinimizeButton:SetScript("OnClick", function() f:SetCollapsed(not f:IsCollapsed()) end)
  return f
end
local quests, achievements
local function Tracker(late)
  ObjectiveTrackerFrame = Section("ObjectiveTrackerFrame")
  ObjectiveTrackerFrame.modules = {}
  function ObjectiveTrackerFrame:AddModule(module) table.insert(self.modules, module) end
  quests, achievements = Section("QuestObjectiveTracker"), Section("AchievementObjectiveTracker")
  if not late then ObjectiveTrackerFrame:AddModule(quests) ObjectiveTrackerFrame:AddModule(achievements) end
  return ObjectiveTrackerFrame
end
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 50 do M.RunTimer() n = n + 1 end end
-- every timer but the later tries of Clara's fold (the same function queued at 0, 1, 3, 6 and 11 seconds)
local function RunFirstTries()
  local seen = {}
  for _, fn in ipairs(M.timers or {}) do seen[fn] = (seen[fn] or 0) + 1 end
  local tries
  for fn, n in pairs(seen) do if n >= 5 then tries = fn end end
  local keep, first = {}, false
  while M.timers and #M.timers > 0 do
    local fn = table.remove(M.timers, 1)
    if fn == tries and first then keep[#keep + 1] = fn else first = first or fn == tries fn() end
  end
  for _, fn in ipairs(keep) do table.insert(M.timers, fn) end
  return tries ~= nil
end
local function Click(owner) local b = owner.Header.MinimizeButton b:GetScript("OnClick")(b) end
local function Kept()
  local all = ClaraComboPointsDB.trackerFolds
  local _, folds = next(all or {})
  return folds or {}
end
local function Login(late)
  local tracker = Tracker(late)
  calls = 0
  M.Fire("ADDON_LOADED", "Blizzard_ObjectiveTracker") -- (the game's tracker loaded: Clara watches its sections)
  Run()
  M.Fire("PLAYER_ENTERING_WORLD", true, false)
  return tracker
end

M.now = 100
local tracker = Tracker()
local ns = {}
S.class = "MAGE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
tracker = Login(); Run()
check(calls == 0 and not tracker.isCollapsed and not quests.isCollapsed, "nothing kept yet: the tracker as the game opens it, untouched")

out("== the Quests section folded with its button")
Click(quests)
check(quests.isCollapsed and Kept().QuestObjectiveTracker == true, "kept at once (no logout needed)")
check(Kept().all == nil, "the whole tracker not kept: left open")

out("== a relog, the game adding its sections seconds after the world shows")
M.now = 200
tracker = Login(true); Run()
check(#tracker.modules == 0 and calls == 0, "no section yet: nothing to fold")
M.now = 205
tracker:AddModule(quests); tracker:AddModule(achievements); Run()
check(quests.isCollapsed and not achievements.isCollapsed and not tracker.isCollapsed,
  "Quests folded as soon as the game added it; Achievements and the tracker left open")
check(calls == 1, "by the game's own fold, once")

out("== something opens it in the first seconds")
M.now = 300
tracker = Login()
check(RunFirstTries(), "the fold tried again over the first seconds")
check(quests.isCollapsed, "folded at once")
M.stack = '[string "@Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.lua"]:476: in function ToggleCollapsed\n'
  .. '[string "@Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_AutoQuestPopUpTracker.lua"]:38: in function AddAutoQuestPopUp'
quests:SetCollapsed(false)
M.stack = nil
M.now = 303; Run()
check(quests.isCollapsed, "folded again by the next tries")
local report = table.concat(ns:TrackerFoldsReport(), "\n")
check(report:find("kept QuestObjectiveTracker", 1, true) ~= nil, "mouse report: what is kept")
check(report:find("QuestObjectiveTracker opened by Blizzard_AutoQuestPopUpTracker:38", 1, true) ~= nil,
  "mouse report: who opened it")
check(report:find("QuestObjectiveTracker folded by Clara", 1, true) ~= nil, "mouse report: Clara's folds")

out("== the game opens it later: kept anyway for the next login")
M.now = 330
quests:SetCollapsed(false)
check(Kept().QuestObjectiveTracker == true, "not the player's click: still kept")
M.now = 400
tracker = Login(); Run()
check(quests.isCollapsed, "folded again at the next login")

out("== the player opens it in the first seconds")
M.now = 500
tracker = Login()
RunFirstTries()
Click(quests)
check(not quests.isCollapsed and Kept().QuestObjectiveTracker == nil, "opened by a click: no longer kept")
Run()
check(not quests.isCollapsed, "not folded again after the player's click")
check(ClaraComboPointsDB.trackerFolds == nil, "nothing folded: nothing kept")
check(table.concat(ns:TrackerFoldsReport(), "\n"):find("QuestObjectiveTracker opened by click", 1, true) ~= nil,
  "mouse report: the player's click")

out("== the whole tracker folded, a reload in combat")
Click(tracker)
check(Kept().all == true, "the whole tracker kept")
M.now = 600
tracker = Tracker(); calls = 0
S.inCombat = true
M.Fire("PLAYER_ENTERING_WORLD", false, true); Run()
check(not tracker.isCollapsed and calls == 0, "in combat: not touched")
M.now = 640
S.inCombat = false; M.Fire("PLAYER_REGEN_ENABLED"); Run()
check(tracker.isCollapsed and not quests.isCollapsed, "the fight over: folded (the sections left open)")

out("== a zone change")
tracker.isCollapsed = false; calls = 0
M.now = 700
M.Fire("PLAYER_ENTERING_WORLD", false, false); Run()
check(calls == 0 and not tracker.isCollapsed, "a zone change: nothing")

out("== a logout")
M.Fire("PLAYER_LOGOUT")
check(Kept().all == true, "the logout changes nothing kept (the tracker open by the game then)")
out(string.format("\n%d failure(s)", fails))
return fails
