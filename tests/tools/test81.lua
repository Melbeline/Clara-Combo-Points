-- The stopwatch kept for each character (GameFixes.lua): through a reload (the time away to the millisecond) and
-- a logout (another character played meanwhile, the time going on), paused as it was, another character's its own
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 50 do M.RunTimer() n = n + 1 end end
local guid = "Player-1-A"
UnitGUID = function(u) if u == "player" then return guid end end
-- the game's stopwatch (Blizzard_TimeManager), cleared and shut at each load
local function Game()
  StopwatchFrame = CreateFrame("Frame", "StopwatchFrame", UIParent); StopwatchFrame:Hide()
  StopwatchTicker = CreateFrame("Frame", "StopwatchTicker", StopwatchFrame); StopwatchTicker.timer = 0
  local playing = false
  function Stopwatch_Play() playing = true end
  function Stopwatch_Pause() playing = false end
  function Stopwatch_IsPlaying() return playing end
  function StopwatchTicker_Update() end
end
Game()
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.now = 1000
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false); Run()
local function Session(who, reload, wait)
  M.Fire("PLAYER_LOGOUT")
  M.now = M.now + wait
  guid = who
  Game()
  M.Fire("PLAYER_ENTERING_WORLD", not reload, reload); Run()
end

out("== a reload")
StopwatchFrame:Show(); Stopwatch_Play(); StopwatchTicker.timer = 125
Session("Player-1-A", true, 4.5)
check(StopwatchFrame:IsShown() and Stopwatch_IsPlaying(), "shown and running again")
check(math.abs(StopwatchTicker.timer - 129.5) < .01, "its time: where it was, plus the reload's 4.5 s (" .. StopwatchTicker.timer .. ")")

out("== another character, then back")
Session("Player-1-B", false, 60)
check(not StopwatchFrame:IsShown() and not Stopwatch_IsPlaying(), "another character: no stopwatch")
Session("Player-1-A", false, 600)
check(StopwatchFrame:IsShown() and Stopwatch_IsPlaying(), "back on the first: shown and running")
check(math.abs(StopwatchTicker.timer - (129.5 + 660)) < .01, "its time: the 11 minutes away counted (" .. StopwatchTicker.timer .. ")")

out("== paused")
Stopwatch_Pause(); StopwatchTicker.timer = 300
Session("Player-1-A", false, 3600)
check(StopwatchFrame:IsShown() and not Stopwatch_IsPlaying() and StopwatchTicker.timer == 300, "paused: back as it was, nothing added")

out("== a countdown that ran out meanwhile, and one cleared")
StopwatchTicker.reverse = true; StopwatchTicker.timer = 30; Stopwatch_Play()
Session("Player-1-A", false, 60)
check(not StopwatchFrame:IsShown(), "ran out while away: not shown again")
Session("Player-1-A", false, 5)
check(not StopwatchFrame:IsShown() and (ClaraComboPointsDB.stopwatch == nil or ClaraComboPointsDB.stopwatch["Player-1-A"] == nil), "nothing kept: nothing comes back")
out(string.format("\n%d failure(s)", fails))
return fails
