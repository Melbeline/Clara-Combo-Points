-- Leatrix Plus's flight bar (Show flight times) kept through a reload or a relog during the flight: the flight saved as it
-- begins (where to, how long, when: the game's clock and the server's), its bar put back at the login with the time left
-- (the game's clock while it runs from the same start, the server's after a restart), as far along as the flight;
-- forgotten at the landing, when the bar is stopped, or when the player is no longer on a taxi.
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local f = io.open(ADDON_DIR .. "/Modules/LeatrixPlus/Leatrix_Plus.lua", "rb")
if not f then out("(no Leatrix Plus in this version)"); out(""); out("0 failure(s)"); return end
local src = f:read("*a"); f:close()
local a = src:find("\t\t\tlocal RememberFlight\n", 1, true)
local b = src:find("\t\t\t-- Show progress bar when flight is taken", 1, true)
local c = src:find("\t\t\t-- A flight in progress at the login", 1, true)
local d = src:find("\t\t\tLeaPlusLC.RestoreFlight = RestoreFlight", 1, true)
check(a and b and c and d and a < b and c < d, "its code found")
if not (a and b and c and d) then out(""); out(fails .. " failure(s)"); return end
local chunk = "return function() " .. src:sub(a, b - 1)
  .. "\nlocal function CeaseProgress() if LeaPlusLC.FlightProgressBar then LeaPlusLC.FlightProgressBar:Stop() LeaPlusLC.FlightProgressBar = nil end end\n"
  .. src:sub(c, d - 1) .. "\nreturn StartFlightBar, RestoreFlight, ForgetFlight end"

local now, server, onTaxi = 1000, 50000, true
local timers = {}
local bars = {}
local env
local function Region() return { ClearAllPoints = function() end, SetPoint = function() end } end
local function Bar()
  local bar = { candyBarLabel = Region(), candyBarBackground = Region() }
  for _, m in ipairs({ "SetPoint", "SetScale", "SetWidth", "AddUpdateFunction", "SetColor", "SetShadowColor", "SetScript", "SetTexture",
    "SetLabel", "SetFill", "EnableMouse" }) do bar[m] = function() end end
  function bar:SetLabel(t) self.label = t end
  function bar:SetDuration(t) self.duration = t end
  function bar:Start(max) self.started = true; self.max = max end
  function bar:Stop() self.stopped = true; if self.claraFlight then self.claraFlight = nil; env.Forget() end end -- (the lib's Stop callback)
  bars[#bars + 1] = bar
  return bar
end
local events = {}
env = setmetatable({
  candy = { New = function() return Bar() end }, texture = "t", faction = "Alliance",
  L = setmetatable({}, { __index = function(_, k) return k end }),
  LeaPlusLC = { FlightBarA = "TOP", FlightBarR = "TOP", FlightBarX = 0, FlightBarY = 0, FlightBarScale = 2, FlightBarWidth = 230,
    FlightBarSpeech = "Off", FlightBarBackground = "On", FlightBarDestination = "On", FlightBarFillBar = "Off" },
  LeaPlusCB = {}, UIParent = {},
  ClaraNS = { sv = {} },
  UnitGUID = function() return "Player-1-0042" end,
  GetTime = function() return now end, GetServerTime = function() return server end,
  UnitOnTaxi = function() return onTaxi end,
  C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
  flightFrame = { SetScript = function(self, _, fn) self.fn = fn end, RegisterEvent = function(self, e) events[e] = true end,
    UnregisterEvent = function(self, e) events[e] = nil end },
}, { __index = _G })
local fn = assert(loadstring(chunk, "@flight"))()
setfenv(fn, env)
local Start, Restore, Forget = fn()
env.Forget = Forget
local store = function() return env.ClaraNS.sv.flightBars and env.ClaraNS.sv.flightBars["Player-1-0042"] end

out("== a flight taken: its bar, the flight saved")
Start(120, "Ironforge")
local s = store()
check(bars[1].duration == 120 and bars[1].max == nil and bars[1].label == "Ironforge", "the bar: 120 s, from the start")
check(s and s.dest == "Ironforge" and s.total == 120 and s.up == 1000 and s.wall == 50000, "saved: where to, how long, when")

out("== a /reload 30 s later: the bar put back, 90 s left, as far along as the flight")
env.LeaPlusLC.FlightProgressBar = nil
now, server = 1030.4, 50030
Restore(true)
local b2 = bars[#bars]
check(#bars == 2 and math.abs(b2.duration - 89.6) < 0.01 and b2.max == 120, "90 s left of 120 (" .. tostring(b2.duration) .. "), the bar a quarter along")
check(store() and store().up == 1000 and store().wall == 50000, "the flight's start kept as it was")
check(events.PLAYER_CONTROL_GAINED, "the landing watched")

out("== the game restarted (its clock from another start): the server's clock")
env.LeaPlusLC.FlightProgressBar = nil
now, server = 12, 50060
Restore(true)
check(math.abs(bars[#bars].duration - 60) < 0.01, "60 s left (" .. tostring(bars[#bars].duration) .. ")")

out("== landed: the bar gone, the flight forgotten")
env.flightFrame.fn()
check(bars[#bars].stopped and store() == nil and not events.PLAYER_CONTROL_GAINED, "stopped, forgotten")

out("== not on a taxi at the login: looked at once more, then forgotten")
Start(200, "Stormwind")
env.LeaPlusLC.FlightProgressBar = nil
onTaxi = false
local count = #bars
Restore(true)
check(#bars == count and store() ~= nil and #timers >= 1, "not yet: once more a little later")
timers[#timers]()
check(#bars == count and store() == nil, "still not on a taxi: forgotten, no bar")

out("== the flight's time already past: no bar")
onTaxi = true
now, server = 2000, 60000
Start(100, "Darnassus")
env.LeaPlusLC.FlightProgressBar = nil
count = #bars
now, server = 2150, 60150
Restore(true)
check(#bars == count and store() == nil, "nothing put back")

out("== the bar stopped by hand (right click, Close Bar): forgotten")
Start(100, "Menethil")
env.LeaPlusLC.FlightProgressBar:Stop()
check(store() == nil, "forgotten")

out("")
out(fails .. " failure(s)")
