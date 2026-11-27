-- Clara Combo Points - /cl perf [seconds]: which addon makes the game halt. For the time asked (20 seconds by default,
-- 5 to 120), every frame, each loaded addon's own time in that frame as the game's addon profiler measures it
-- (C_AddOnProfiler, LastTime: the milliseconds the addon's code took in the last frame), and all of them together.
-- Then in the chat: the worst frames (when, how long the addons took in all, the three that took the most), and each
-- addon's worst frame and how many of its frames went over 5 ms. Clara's modules count as Clara itself (the game
-- measures by addon). Nothing is kept; only what is asked for is written. Without the game's profiler: said.
-- /cl perf chargement (load, laden): the next loading screen measured instead (a zone left, a portal, an instance, a
-- /reload or a login: kept for the next one, through a reload too). From the loading screen shown to a second after it
-- goes, each addon's time in each frame summed; and at the end the game's own count for the last 60 frames (the
-- frames of the loading itself, in case the game runs none of the addons' updates while it lasts); each addon's slowest
-- frame in it, and its frames over 100 ms. Then in the chat: how long it lasted, the addons' time in all, the
-- costliest addons first. Once, then forgotten.

local ADDON, ns = ...
local L = ns.L

local DEFAULT, MIN, MAX = 20, 5, 120 -- seconds
local SLOW = 5                         -- ms: a frame an addon slowed
local WORST = 5                        -- the worst frames listed
local TOP = 8                          -- the addons listed

local watching
local frame = CreateFrame("Frame")
frame:Hide()

local function Say(text) print("|cffffd200Clara|r: " .. text) end

local function Available()
  local P = C_AddOnProfiler
  local M = Enum and Enum.AddOnProfilerMetric
  if not (P and P.GetAddOnMetric and M and M.LastTime) then return false end
  if P.IsEnabled then
    local ok, on = pcall(P.IsEnabled)
    if ok and on == false then return false end
  end
  return true
end

-- The loaded addons' names
local function Loaded()
  local A, out = C_AddOns, {}
  if not (A and A.GetNumAddOns and A.GetAddOnInfo and A.IsAddOnLoaded) then return out end
  for i = 1, A.GetNumAddOns() do
    local name = A.GetAddOnInfo(i)
    if type(name) == "string" and A.IsAddOnLoaded(i) then out[#out + 1] = name end
  end
  return out
end

local function Report()
  local w = watching
  watching = nil
  frame:Hide()
  if not w then return end
  Say(L.PERF_DONE:format(w.frames, w.seconds))
  table.sort(w.worst, function(a, b) return a.total > b.total end)
  if #w.worst == 0 or w.worst[1].total < 1 then Say(L.PERF_QUIET) end
  for i = 1, math.min(WORST, #w.worst) do
    local f = w.worst[i]
    local parts = {}
    for k = 1, math.min(3, #f.top) do parts[k] = ("%s %.1f ms"):format(f.top[k][1], f.top[k][2]) end
    Say(L.PERF_FRAME:format(f.at - w.started, f.total, table.concat(parts, ", ")))
  end
  local list = {}
  for name, peak in pairs(w.peak) do if peak > 0 then list[#list + 1] = name end end
  table.sort(list, function(a, b) return w.peak[a] > w.peak[b] end)
  for i = 1, math.min(TOP, #list) do
    local name = list[i]
    Say(L.PERF_ADDON:format(name, w.peak[name], w.slow[name] or 0, SLOW))
  end
end

frame:SetScript("OnUpdate", function()
  local w = watching
  if not w then frame:Hide() return end
  local now = GetTime()
  if now >= w.started + w.seconds then Report() return end
  local P, LAST = C_AddOnProfiler, Enum.AddOnProfilerMetric.LastTime
  local total, top = 0, nil
  for _, name in ipairs(w.names) do
    local ok, ms = pcall(P.GetAddOnMetric, name, LAST)
    if ok and type(ms) == "number" and ms > 0 then
      total = total + ms
      if ms > (w.peak[name] or 0) then w.peak[name] = ms end
      if ms > SLOW then w.slow[name] = (w.slow[name] or 0) + 1 end
      if ms >= 1 then
        top = top or {}
        top[#top + 1] = { name, ms }
      end
    end
  end
  w.frames = w.frames + 1
  -- the worst frames kept (a few, the slowest)
  if total >= 1 then
    local worst = w.worst
    if #worst < WORST or total > worst[#worst].total then
      if top then table.sort(top, function(a, b) return a[2] > b[2] end) end
      worst[#worst + 1] = { at = now, total = total, top = top or {} }
      table.sort(worst, function(a, b) return a.total > b.total end)
      if #worst > WORST then worst[#worst] = nil end
    end
  end
end)

---------------------------------------------------------------------------
-- /cl perf chargement: the next loading screen
---------------------------------------------------------------------------
local AFTER = 1    -- second: watched after the loading screen goes (the addons' work as the world comes)
local WORLD = 3    -- seconds after the world entered: the loading taken as over if its screen's end was not seen
local LONGEST = 60 -- seconds: a measure never runs longer
local SHOWN = 10   -- the addons listed
local BIG = 100    -- ms: a frame that halts
local function Met(key, fallback)
  local E = Enum and Enum.AddOnProfilerMetric
  return E and E[key] or fallback
end
local function Metric(name, metric)
  local ok, v = pcall(C_AddOnProfiler.GetAddOnMetric, name, metric)
  return ok and type(v) == "number" and v or 0
end
local function Snapshot()
  local s, peak, over = {}, Met("PeakTime", 4), Met("CountTimeOver100Ms", 9)
  for _, name in ipairs(Loaded()) do s[name] = { peak = Metric(name, peak), over = Metric(name, over) } end
  return s
end
local function Armed() return ns.sv and ns.sv.perfLoad == true end

local loading
local loader = CreateFrame("Frame")
loader:Hide()

local function LoadReport()
  local l = loading
  loading = nil
  loader:Hide()
  if ns.sv then ns.sv.perfLoad, ns.sv.perfLoadBase = nil, nil end
  if not l or not Available() then return end
  local ok, err = pcall(function()
    local recentM, peakM, overM = Met("RecentAverageTime", 1), Met("PeakTime", 4), Met("CountTimeOver100Ms", 9)
    local rows, all = {}, 0
    for _, name in ipairs(Loaded()) do
      local total = math.max(l.sum[name] or 0, Metric(name, recentM) * 60)
      local b = l.base and l.base[name]
      local peakNow, overNow = Metric(name, peakM), Metric(name, overM)
      if b and peakNow + 0.001 < (b.peak or 0) then b = nil end -- (the game started again since: counted from its start)
      local peak = l.top[name] or 0
      if not b or peakNow > (b.peak or 0) + 0.001 then peak = math.max(peak, peakNow) end -- (a new slowest frame: this loading's)
      local over = math.max(0, overNow - (b and b.over or 0))
      all = all + total
      if total >= 1 or peak >= 1 then rows[#rows + 1] = { name = name, total = total, peak = peak, over = over } end
    end
    table.sort(rows, function(a, b) return a.total > b.total end)
    if l.ms then Say(L.PERF_LOAD_DONE:format(l.ms / 1000, all)) else Say(L.PERF_LOAD_LOGIN:format(all)) end
    if #rows == 0 then Say(L.PERF_LOAD_QUIET) end
    for i = 1, math.min(SHOWN, #rows) do
      local r = rows[i]
      Say(L.PERF_LOAD_ADDON:format(i, r.name, r.total, r.peak, r.over, BIG))
    end
  end)
  if not ok then Say("/cl perf: " .. tostring(err)) end
end

loader:SetScript("OnUpdate", function()
  local l = loading
  if not l then loader:Hide() return end
  local last = Met("LastTime", 3)
  for _, name in ipairs(l.names) do
    local ms = Metric(name, last)
    if ms > 0 then
      l.sum[name] = (l.sum[name] or 0) + ms
      if ms > (l.top[name] or 0) then l.top[name] = ms end
    end
  end
  l.frames = l.frames + 1
  local now = GetTime()
  if (l.ended and now >= l.ended + AFTER) or now >= l.started + LONGEST then LoadReport() end
end)

local function LoadStart(base, login)
  if loading or not Available() then return end
  loading = { base = base or Snapshot(), names = Loaded(), sum = {}, top = {}, frames = 0, started = GetTime(),
    t0 = not login and debugprofilestop and debugprofilestop() or nil }
  loader:Show()
  Say(login and L.PERF_LOAD_LOGIN_START or L.PERF_LOAD_START)
end

local loadEvents = CreateFrame("Frame")
for _, e in ipairs({ "LOADING_SCREEN_ENABLED", "LOADING_SCREEN_DISABLED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT" }) do
  pcall(loadEvents.RegisterEvent, loadEvents, e)
end
loadEvents:SetScript("OnEvent", function(_, event)
  if event == "LOADING_SCREEN_ENABLED" then
    if Armed() then LoadStart() end
  elseif event == "LOADING_SCREEN_DISABLED" then
    local l = loading
    if l and not l.ended then
      l.ended = GetTime()
      if l.t0 then l.ms = debugprofilestop() - l.t0 end
    end
  elseif event == "PLAYER_LOGIN" then
    -- (armed before a reload or a logout: this login is the loading measured, from what was seen as it began)
    if Armed() then LoadStart(type(ns.sv.perfLoadBase) == "table" and ns.sv.perfLoadBase or nil, true) end
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- (no loading screen's end told, as when it went before Clara was there: the world is there, ended a moment later)
    local l = loading
    if l and C_Timer and C_Timer.After then
      C_Timer.After(WORLD, function() if loading == l and not l.ended then l.ended = GetTime() end end)
    end
  elseif event == "PLAYER_LOGOUT" then
    if Armed() and Available() then ns.sv.perfLoadBase = Snapshot() end -- (a reload or a logout: where things stood)
  end
end)

-- /cl perf [seconds] · /cl perf chargement
function ns.PerfWatch(seconds)
  if type(seconds) == "string" then
    local word = seconds:lower()
    if word:find("^charg") or word:find("^load") or word:find("^lad") then
      if not Available() then Say(L.PERF_NONE) return end
      if not ns.sv then return end
      ns.sv.perfLoad = true
      Say(L.PERF_LOAD_ARMED)
      return
    end
  end
  if watching then Say(L.PERF_BUSY) return end
  if not Available() then Say(L.PERF_NONE) return end
  seconds = math.max(MIN, math.min(MAX, math.floor(tonumber(seconds) or DEFAULT)))
  watching = { started = GetTime(), seconds = seconds, names = Loaded(), peak = {}, slow = {}, worst = {}, frames = 0 }
  Say(L.PERF_START:format(seconds))
  frame:Show()
end
ns.PerfReport, ns.PerfFrame, ns.PerfLoader = Report, frame, loader -- (for the tests)
