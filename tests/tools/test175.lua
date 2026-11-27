-- /cl perf (Perf.lua): for the seconds asked, each loaded addon's time in each frame read from the game's addon
-- profiler (LastTime); then in the chat: the worst frames (when, the addons' time in all, the three that took the
-- most) and each addon's worst frame and its frames over 5 ms, the costliest first. Without the profiler: said.
-- /cl perf chargement: the next loading screen (or the login after a reload) measured, once: each addon's time summed
-- frame by frame or the game's count for the last 60 frames (the bigger), its slowest frame in it, its frames over 100 ms.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local said = {}
local oldPrint = print
print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end said[#said + 1] = table.concat(t, " ") end
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.PerfWatch then print = oldPrint; out("(no /cl perf in this version)"); out(""); out("0 failure(s)"); return end
out("== no profiler: said")
C_AddOnProfiler = nil
ns.PerfWatch(10)
check(said[#said] and said[#said]:find(ns.L.PERF_NONE, 1, true), "said: " .. tostring(said[#said]))
out("== watched: each frame's times, then the worst")
Enum = Enum or {}
Enum.AddOnProfilerMetric = { LastTime = 3 }
local times = {}
C_AddOnProfiler = { IsEnabled = function() return true end, GetAddOnMetric = function(name, metric) return metric == 3 and times[name] or 0 end }
local names = { "ClaraComboPoints", "Questie", "Details" }
C_AddOns = C_AddOns or {}
C_AddOns.GetNumAddOns = function() return #names end
C_AddOns.GetAddOnInfo = function(i) return names[i] end
C_AddOns.IsAddOnLoaded = function(i) return type(i) == "number" or i == "ClaraComboPoints" end
local now = 100
GetTime = function() return now end
SlashCmdList.CLARACOMBOPOINTS("perf 10")
check(said[#said]:find("10 s", 1, true) ~= nil, "started, for 10 s: " .. tostring(said[#said]))
local up = ns.PerfFrame:GetScript("OnUpdate")
local frames = {
  { ClaraComboPoints = 0.4, Questie = 0.2 },
  { ClaraComboPoints = 0.5, Questie = 31.5, Details = 2 }, -- (the halt: Questie)
  { ClaraComboPoints = 6.2, Questie = 0.1 },
  { ClaraComboPoints = 0.3 },
}
for i, f in ipairs(frames) do times = f; now = 100 + i; up(ns.PerfFrame) end
now = 111; up(ns.PerfFrame)
local all = table.concat(said, "\n")
check(all:find("4 frames watched in 10 s", 1, true) ~= nil, "the frames counted")
local worst = all:match("at 2%.0 s: the addons took 34%.0 ms in all %(([^)]*)%)")
check(worst and worst:find("^Questie 31%.5 ms, Details 2%.0 ms") ~= nil, "the worst frame first, Questie the most: " .. tostring(worst))
local q, c = all:find("Questie: its worst frame 31.5 ms, 1 frames over 5 ms", 1, true), all:find("ClaraComboPoints: its worst frame 6.2 ms, 1 frames over 5 ms", 1, true)
check(q and c and q < c, "each addon's worst, the costliest first")
check(not ns.PerfFrame:IsShown(), "done: stopped")

out("== /cl perf chargement: the next loading screen")
Enum.AddOnProfilerMetric = { RecentAverageTime = 1, LastTime = 3, PeakTime = 4, CountTimeOver100Ms = 9 }
local metric = { [1] = {}, [3] = {}, [4] = { Questie = 40, ClaraComboPoints = 6.2 }, [9] = { Questie = 2 } }
C_AddOnProfiler.GetAddOnMetric = function(name, m) return metric[m] and metric[m][name] or 0 end
local clock = 5000
debugprofilestop = function() return clock end
for k in pairs(said) do said[k] = nil end
SlashCmdList.CLARACOMBOPOINTS("perf chargement")
check(said[#said] == "|cffffd200Clara|r: " .. ns.L.PERF_LOAD_ARMED and ClaraComboPointsDB.perfLoad == true, "armed, kept: " .. tostring(said[#said]))
check(not ns.PerfLoader:IsShown(), "nothing watched before the loading screen")
now = 200
M.Fire("LOADING_SCREEN_ENABLED")
check(ns.PerfLoader:IsShown(), "the loading screen shown: watched")
check(said[#said] == "|cffffd200Clara|r: " .. ns.L.PERF_LOAD_START, "said as it starts: " .. tostring(said[#said]))
local load = ns.PerfLoader:GetScript("OnUpdate")
-- frames during and after the loading: each addon's time in each
local seen = { { Questie = 180, Details = 3 }, { Questie = 420, ClaraComboPoints = 12 }, { ClaraComboPoints = 2 } }
for i, f in ipairs(seen) do metric[3] = f; now = 200 + i; load(ns.PerfLoader) end
metric[4].Questie = 420; metric[9].Questie = 4 -- (its slowest frame since the game started: this loading's; 2 more over 100 ms)
metric[1] = { Questie = 12, ClaraComboPoints = 0.1, Details = 0.1 } -- (the game's last 60 frames: 720, 6, 6 ms)
clock = 9200
M.Fire("LOADING_SCREEN_DISABLED")
metric[3] = {}
now = 203.5; load(ns.PerfLoader)
check(ns.PerfLoader:IsShown(), "a second after it still watched")
now = 206; load(ns.PerfLoader)
local all2 = table.concat(said, "\n")
check(all2:find("loading screen measured: 4.2 s; the addons took 7", 1, true) ~= nil, "its length and the addons' time in all: " .. tostring(said[3]))
local q2 = all2:find("1. Questie: 720 ms, its slowest frame 420 ms, 2 frames over 100 ms", 1, true)
local c2 = all2:find("2. ClaraComboPoints: 14 ms, its slowest frame 12 ms, 0 frames over 100 ms", 1, true)
check(q2 and c2 and q2 < c2, "the costliest first: the game's count when bigger (Questie), the frames summed when bigger (Clara)")
check(all2:find("Details: 6 ms", 1, true) ~= nil, "Details: " .. tostring(all2:match("[^\n]*Details[^\n]*")))
check(not ns.PerfLoader:IsShown() and ClaraComboPointsDB.perfLoad == nil, "once, then forgotten")
for k in pairs(said) do said[k] = nil end
M.Fire("LOADING_SCREEN_ENABLED")
check(not ns.PerfLoader:IsShown(), "the next loading screen: not measured")
out("== armed, then a reload: the login measured, from where things stood at the logout")
SlashCmdList.CLARACOMBOPOINTS("perf load")
metric[4].Questie = 420; metric[9].Questie = 4
M.Fire("PLAYER_LOGOUT")
check(type(ClaraComboPointsDB.perfLoadBase) == "table" and ClaraComboPointsDB.perfLoadBase.Questie.peak == 420, "where things stood kept for the reload")
now = 299
M.Fire("PLAYER_LOGIN")
check(ns.PerfLoader:IsShown(), "the login watched")
check(said[#said] == "|cffffd200Clara|r: " .. ns.L.PERF_LOAD_LOGIN_START, "said as it starts: " .. tostring(said[#said]))
metric[3] = { Questie = 30 }; now = 300; load(ns.PerfLoader)
metric[1] = { Questie = 0.5 }
M.Fire("LOADING_SCREEN_DISABLED")
metric[3] = {}; now = 302; load(ns.PerfLoader)
all2 = table.concat(said, "\n")
out("== the loading screen's end not seen (gone before Clara was there): over a few seconds after the world entered")
SlashCmdList.CLARACOMBOPOINTS("perf load")
now = 400
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", false, true)
now = 401; load(ns.PerfLoader)
check(ns.PerfLoader:IsShown(), "still watched just after")
for _ = 1, #(M.timers or {}) do M.RunTimer() end -- (the world's few seconds)
now = 404.5; load(ns.PerfLoader)
check(not ns.PerfLoader:IsShown() and said[#said - 1]:find("login measured", 1, true) ~= nil, "measured a few seconds after the world entered: " .. tostring(said[#said - 1]))
out("== a measure never runs past a minute")
SlashCmdList.CLARACOMBOPOINTS("perf load")
now = 500
M.Fire("LOADING_SCREEN_ENABLED")
now = 561; load(ns.PerfLoader)
check(not ns.PerfLoader:IsShown(), "stopped after a minute, said all the same")
check(all2:find("login measured: the addons took 30 ms", 1, true) ~= nil and all2:find("1. Questie: 30 ms, its slowest frame 30 ms, 0 frames over 100 ms", 1, true) ~= nil,
  "the login's own: its slowest frame not the older one: " .. all2)
print = oldPrint
out("")
out(fails .. " failure(s)")
