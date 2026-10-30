-- Profiler bench: the addon through a login, then a minute out of combat and a minute in combat
-- (60 frames a second, the game's usual events), time and garbage per handler.
-- BENCH_CLASS, BENCH_MODULES (comma list of QoL modules on), BENCH_SECONDS from the environment.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local clock = os.clock
local CLASS = os.getenv("BENCH_CLASS") or "ROGUE"
local SECONDS = tonumber(os.getenv("BENCH_SECONDS") or "60")
local ON = {}
for k in (os.getenv("BENCH_MODULES") or ""):gmatch("[^,]+") do ON[k] = true end

local prof, active = {}, false
local function Key(fn, what)
  local i = debug.getinfo(fn, "S")
  return (i.short_src or "?"):gsub("^.*ClaraComboPoints/", "") .. ":" .. (i.linedefined or 0) .. " " .. what
end
local depth = 0
local function Finish(p, m0, t0, ok, ...)
  p.t = p.t + clock() - t0
  p.kb = p.kb + collectgarbage("count") - m0
  p.n = p.n + 1
  depth = depth - 1
  if not ok then error((...), 0) end
  return ...
end
local function Wrap(fn, what, byEvent)
  local base = Key(fn, what)
  local byKey = {}
  return function(...)
    if not active or depth > 0 then return fn(...) end
    local k = base
    if byEvent then
      local e = select(2, ...)
      k = byKey[e]
      if not k then k = base .. " " .. tostring(e) byKey[e] = k end
    end
    local p = prof[k]
    if not p then p = { t = 0, kb = 0, n = 0 } prof[k] = p end
    depth = depth + 1
    local m0, t0 = collectgarbage("count"), clock()
    return Finish(p, m0, t0, pcall(fn, ...))
  end
end
local Frame = M.classes.Frame
local SetScript = Frame.SetScript
Frame.SetScript = function(self, name, fn)
  if fn and (name == "OnUpdate" or name == "OnEvent") then fn = Wrap(fn, name, name == "OnEvent") end
  return SetScript(self, name, fn)
end
local After = C_Timer.After
C_Timer.After = function(d, fn) return After(d, Wrap(fn, "timer")) end

-- the character
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
local qol = {}
for _, k in ipairs({ "buyemall", "leatrix", "nodesight", "wst", "dynamiccam", "dialogkey", "xtolevel", "minimapdrawer", "mail", "classicui" }) do
  qol[k] = ON[k] or false
end
ClaraComboPointsDB = { qol = qol }
S.class = CLASS; S.locale = "enUS"
S.powerType = (CLASS == "ROGUE") and 3 or (CLASS == "WARRIOR" and 1 or 0)
S.energy, S.rage, S.mana, S.manaMax, S.health, S.healthMax = 100, 0, 3000, 3000, 2000, 2000
M.now = 1000

-- loading, file by file
local loadT, loadKB = {}, {}
local ns = {}
do
  local toc = assert(io.open(ADDON_DIR .. "/ClaraComboPoints.toc", "rb")):read("*a")
  for file in toc:gmatch("[^\r\n]+") do
    if not file:match("^##") and file:match("%.lua$") then
      local f = assert(io.open(ADDON_DIR .. "/" .. file:gsub("\\", "/"), "rb"))
      local src = f:read("*a"); f:close()
      local m0, t0 = collectgarbage("count"), clock()
      local chunk = assert(loadstring(src, "@" .. file))
      local ok, err = pcall(chunk, "ClaraComboPoints", ns)
      loadT[#loadT + 1] = { file, clock() - t0, collectgarbage("count") - m0, ok or err }
    end
  end
end
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local t0 = clock()
M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local loginT = clock() - t0

-- a few icons: the class's defaults, and some auras to show
local SPELLS = { ROGUE = { 1784, 5171, 2983, 1966 }, WARRIOR = { 6673, 772, 7386 }, MAGE = { 1459, 168 }, DRUID = { 774, 8921, 1126 } }
S.auras = {
  player = { { name = "Slice and Dice", icon = 132306, duration = 20, expirationTime = 1020, id = 1, spellId = 5171 },
    { name = "Arcane Intellect", icon = 135932, duration = 1800, expirationTime = 2800, id = 2, spellId = 1459 } },
  target = { { name = "Rend", icon = 132155, duration = 15, expirationTime = 1015, id = 3, spellId = 772, harmful = true } },
}
S.target = { cp = 2, hostile = true, name = "Defias" }
M.Fire("PLAYER_TARGET_CHANGED")

local function Run(label, fight)
  if fight then
    S.inCombat = true
    M.Fire("PLAYER_REGEN_DISABLED")
  end
  collectgarbage("collect")
  collectgarbage("stop")
  prof = {}
  active = true
  local frames = SECONDS * 60
  local m0, c0 = collectgarbage("count"), clock()
  for i = 1, frames do
    M.now = M.now + 1 / 60
    if i % 6 == 0 then
      S.energy = (S.energy + 2) % 101
      M.Fire("UNIT_POWER_FREQUENT", "player", "ENERGY")
    end
    if i % 30 == 0 then M.Fire("UNIT_AURA", "player"); M.Fire("UNIT_AURA", "target") end
    if i % 12 == 0 then M.Fire("UNIT_HEALTH", "target") end
    if i % 30 == 15 then M.Fire("SPELL_UPDATE_COOLDOWN") end
    if fight and i % 60 == 0 then
      M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c", 1752)
      S.target.cp = (S.target.cp + 1) % 6
    end
    if i % 600 == 0 then M.Fire("BAG_UPDATE_DELAYED") end
    M.Frame(1 / 60)
    while M.timers and #M.timers > 0 do M.RunTimer() end
  end
  active = false
  local total, kb = clock() - c0, collectgarbage("count") - m0
  collectgarbage("restart")
  out(("== %s: %.1f ms a second of play (mock), %.1f KB garbage a second"):format(label, total * 1000 / SECONDS, kb / SECONDS))
  local list = {}
  for k, p in pairs(prof) do list[#list + 1] = { k, p } end
  table.sort(list, function(a, b) return a[2].t > b[2].t end)
  for i = 1, math.min(#list, tonumber(os.getenv("BENCH_TOP") or "15")) do
    local k, p = list[i][1], list[i][2]
    out(("  %7.2f ms/s  %7.2f KB/s  %6d calls  %s"):format(p.t * 1000 / SECONDS, p.kb / SECONDS, p.n, k))
  end
end

if ns.db then
  for k, id in ipairs(SPELLS[CLASS] or {}) do ns.db.rows.above[1] = ns.db.rows.above[1] or {}; table.insert(ns.db.rows.above[1], id) end
  ns:LayoutIcons()
end
if os.getenv("BENCH_DEBUG") then
  local fe = ns.ForEachIcon
  local calls = {}
  ns.ForEachIcon = function(self, fn, ...)
    local i = debug.getinfo(fn, "S")
    local k = i.short_src:gsub("^.*/", "") .. ":" .. i.linedefined
    calls[k] = (calls[k] or 0) + 1
    return fe(self, fn, ...)
  end
  for i = 1, 600 do M.now = M.now + 1/60; M.Frame(1/60) end
  for k, n in pairs(calls) do out("ForEachIcon " .. k .. " " .. n) end
end
Run("out of combat", false)
Run("in combat", true)
out(("== login: %.1f ms"):format(loginT * 1000))
if os.getenv("BENCH_LOAD") then
  table.sort(loadT, function(a, b) return a[2] > b[2] end)
  local sum = 0
  for _, l in ipairs(loadT) do sum = sum + l[2] end
  out(("== loading the files: %.1f ms"):format(sum * 1000))
  for i = 1, math.min(#loadT, 25) do
    local l = loadT[i]
    out(("  %7.2f ms  %8.1f KB  %s%s"):format(l[2] * 1000, l[3], l[1], l[4] == true and "" or ("  (error: " .. tostring(l[4]):sub(1, 80) .. ")")))
  end
end
