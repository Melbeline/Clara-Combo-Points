-- Clara Combo Points - /cl perf [seconds]: which addon makes the game halt. For the time asked (20 seconds by default,
-- 5 to 120), every frame, each loaded addon's own time in that frame as the game's addon profiler measures it
-- (C_AddOnProfiler, LastTime: the milliseconds the addon's code took in the last frame), and all of them together.
-- Then in the chat: the worst frames (when, how long the addons took in all, the three that took the most), and each
-- addon's worst frame and how many of its frames went over 5 ms. Clara's modules count as Clara itself (the game
-- measures by addon). Nothing is kept; only what is asked for is written. Without the game's profiler: said.

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

-- /cl perf [seconds]
function ns.PerfWatch(seconds)
  if watching then Say(L.PERF_BUSY) return end
  if not Available() then Say(L.PERF_NONE) return end
  seconds = math.max(MIN, math.min(MAX, math.floor(tonumber(seconds) or DEFAULT)))
  watching = { started = GetTime(), seconds = seconds, names = Loaded(), peak = {}, slow = {}, worst = {}, frames = 0 }
  Say(L.PERF_START:format(seconds))
  frame:Show()
end
ns.PerfReport, ns.PerfFrame = Report, frame -- (for the tests)
