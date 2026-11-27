-- Profiling: the burst of events a quest turned in (or a kill) brings at once, with many reputations changing: each
-- frame's OnEvent timed, by the file that made its handler, and by event. Repeated to make the costs measurable.
local H = ...
local env, ns, frames = H.env, H.ns, H.frames
local REPEAT = tonumber(os.getenv("BURST_REPEAT") or "200")
local byFile, byEvent, calls = {}, {}, {}
local clock = os.clock
-- each frame's OnEvent wrapped with a timer
for i = 1, #frames do
  local f = frames[i]
  local scripts = rawget(f, "__scripts")
  local h = scripts and scripts.OnEvent
  if h and not rawget(f, "__profiled") then
    rawset(f, "__profiled", true)
    local info = debug.getinfo(h, "S")
    local src = (info and info.source or "?"):gsub("^@", "") .. ":" .. tostring(info and info.linedefined)
    scripts.OnEvent = function(self, event, ...)
      local t = clock()
      local r1, r2 = h(self, event, ...)
      local d = clock() - t
      byFile[src] = (byFile[src] or 0) + d
      local k = event .. " | " .. src
      byEvent[k] = (byEvent[k] or 0) + d
      calls[k] = (calls[k] or 0) + 1
      return r1, r2
    end
  end
end
-- the timers the burst sets: their callbacks timed too, by the file that made them
local CT = env.C_Timer
local function Wrap(fn)
  local info = debug.getinfo(fn, "S")
  local k = "timer | " .. (info and info.source or "?"):gsub("^@", "") .. ":" .. tostring(info and info.linedefined)
  return function(...)
    local t = clock()
    fn(...)
    local d = clock() - t
    byFile[k] = (byFile[k] or 0) + d
    byEvent[k] = (byEvent[k] or 0) + d
    calls[k] = (calls[k] or 0) + 1
  end
end
local after, newTimer, newTicker = CT.After, CT.NewTimer, CT.NewTicker
CT.After = function(d, fn) return after(d, Wrap(fn)) end
CT.NewTimer = function(d, fn) return newTimer(d, Wrap(fn)) end
CT.NewTicker = function(d, fn, n) return newTicker(d, Wrap(fn), n) end
local reps = {
  "Reputation with Everlook increased by 50.", "Reputation with Powderfuse increased by 50.",
  "Reputation with Gadgetzan increased by 50.", "Reputation with Steamwheedle Cartel increased by 50.",
  "Reputation with Ratchet increased by 50.", "Reputation with Bloodsail Buccaneers decreased by 500.",
  "Reputation with Booty Bay increased by 100.",
}
local function Burst()
  H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Experience gained: 2884.", "", "", "", "", "", 0, 0, "", 0, 0)
  H.Fire("PLAYER_XP_UPDATE", "player")
  for _, r in ipairs(reps) do
    H.Fire("CHAT_MSG_COMBAT_FACTION_CHANGE", r, "", "", "", "", "", 0, 0, "", 0, 0)
    H.Fire("UPDATE_FACTION")
  end
  H.Fire("CHAT_MSG_LOOT", "You receive item: |cffffffff|Hitem:19970::::::::40:::::::::|h[Goblin Fishing Pole]|h|rx8.", "", "", "", "", "", 0, 0, "", 0, 0)
  for bag = 0, 4 do H.Fire("BAG_UPDATE", bag) end
  H.Fire("BAG_UPDATE_DELAYED")
  H.Fire("UNIT_INVENTORY_CHANGED", "player")
  H.Fire("CHAT_MSG_SYSTEM", "Bloodscalp Ears completed.", "", "", "", "", "", 0, 0, "", 0, 0)
  H.Fire("QUEST_TURNED_IN", 189, 2111, 0)
  H.Fire("QUEST_REMOVED", 189)
  H.Fire("QUEST_LOG_UPDATE")
  H.Fire("UNIT_QUEST_LOG_CHANGED", "player")
  H.Fire("QUEST_WATCH_LIST_CHANGED")
  H.Fire("PLAYER_MONEY")
  H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Experience gained: 2111.", "", "", "", "", "", 0, 0, "", 0, 0)
  H.Fire("PLAYER_XP_UPDATE", "player")
  H.Fire("QUEST_LOG_UPDATE")
end
local t0 = clock()
for _ = 1, REPEAT do Burst(); H.RunTimers() end
local total = clock() - t0
local function Top(t, n, label)
  local list = {}
  for k, v in pairs(t) do list[#list + 1] = { k, v } end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  print(("profile: %s, the %d costliest (ms per burst):"):format(label, n))
  for i = 1, math.min(n, #list) do
    local k, v = list[i][1], list[i][2]
    print(("profile:   %7.3f ms  %s%s"):format(v * 1000 / REPEAT, k, calls[k] and ("  (" .. calls[k] / REPEAT .. " calls)") or ""))
  end
end
print(("profile: %d bursts in %.2f s: %.3f ms a burst, timers included"):format(REPEAT, total, total * 1000 / REPEAT))
Top(byFile, 15, "by file")
Top(byEvent, 25, "by event and file")
