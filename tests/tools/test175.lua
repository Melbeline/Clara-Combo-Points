-- /cl perf (Perf.lua): for the seconds asked, each loaded addon's time in each frame read from the game's addon
-- profiler (LastTime); then in the chat: the worst frames (when, the addons' time in all, the three that took the
-- most) and each addon's worst frame and its frames over 5 ms, the costliest first. Without the profiler: said.
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
print = oldPrint
out("")
out(fails .. " failure(s)")
