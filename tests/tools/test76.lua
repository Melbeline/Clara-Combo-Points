-- The quest tracker folded again as it was left (GameFixes.lua): the whole tracker and each section, for each
-- character; read at logout, folded at login by the game's own fold, out of combat; an open one never touched
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local calls = 0
local function Section(name)
  local f = CreateFrame("Frame", name, UIParent)
  f.isCollapsed = false
  function f:IsCollapsed() return self.isCollapsed end
  function f:SetCollapsed(c) calls = calls + 1 self.isCollapsed = c end
  return f
end
local function Tracker()
  ObjectiveTrackerFrame = Section("ObjectiveTrackerFrame")
  ObjectiveTrackerFrame.modules = { Section("QuestObjectiveTracker"), Section("AchievementObjectiveTracker") }
  return ObjectiveTrackerFrame
end
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 50 do M.RunTimer() n = n + 1 end end

local tracker = Tracker()
local ns = {}
S.class = "MAGE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false); Run()
check(calls == 0 and not tracker.isCollapsed, "nothing saved yet: the tracker as the game opens it, untouched")

out("== folded, then a relog")
tracker.isCollapsed = true; tracker.modules[2].isCollapsed = true
M.Fire("PLAYER_LOGOUT")
tracker = Tracker(); calls = 0
M.Fire("PLAYER_ENTERING_WORLD", true, false); Run()
check(tracker.isCollapsed and tracker.modules[2].isCollapsed and not tracker.modules[1].isCollapsed,
  "folded again: the tracker and the Achievements section; Quests left open")
check(calls == 2, "by the game's own fold, once each")

out("== a reload in combat")
M.Fire("PLAYER_LOGOUT")
tracker = Tracker(); calls = 0
S.inCombat = true
M.Fire("PLAYER_ENTERING_WORLD", false, true); Run()
check(not tracker.isCollapsed and calls == 0, "in combat: not touched")
S.inCombat = false; M.Fire("PLAYER_REGEN_ENABLED"); Run()
check(tracker.isCollapsed and tracker.modules[2].isCollapsed, "the fight over: folded")

out("== opened again, then a relog")
tracker.isCollapsed = false; tracker.modules[2].isCollapsed = false
M.Fire("PLAYER_LOGOUT")
check(ClaraComboPointsDB.trackerFolds == nil, "nothing folded: nothing kept")
tracker = Tracker(); calls = 0
M.Fire("PLAYER_ENTERING_WORLD", true, false); Run()
check(calls == 0 and not tracker.isCollapsed, "left open: untouched")
M.Fire("PLAYER_ENTERING_WORLD", false, false); Run()
check(calls == 0, "a zone change: nothing")
out(string.format("\n%d failure(s)", fails))
return fails
