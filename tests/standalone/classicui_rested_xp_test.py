import sys
from lupa.lua51 import LuaRuntime
L = LuaRuntime(unpack_returned_tuples=True)
src = open(sys.argv[1], encoding='utf-8').read()
loc = open(sys.argv[2], encoding='utf-8').read()
L.execute(r'''
lines = { "XP: 4000 / 16000 (25%)", "Rested\n200% of normal experience gained from monsters." }
local function Line(i) return { GetText = function() return lines[i] end, SetText = function(_, t) lines[i] = t end } end
GameTooltipTextLeft1, GameTooltipTextLeft2 = Line(1), Line(2)
shown = 0
GameTooltip = { IsShown = function() return true end, NumLines = function() return #lines end, Show = function() shown = shown + 1 end }
function GetXPExhaustion() return 1600 end
function UnitXPMax() return 16000 end
function GetRestState() return 1, "Rested", 2 end
function BreakUpLargeNumbers(n) return tostring(n) end
hooks = {}
L = {}
ns = { L = L, db = { xpTipRested = false }, AnySecret = function() return false end, IsSecret = function() return false end,
  EventFrame = function(_, fn) hooks.login = fn end, HookScriptOnce = function(bar, _, fn) hooks.enter = fn end }
ClaraNS = { ClassicUIRuns = true, ClassicUIPrivate = ns, sv = {} }
MainStatusTrackingBarContainer = { bars = { { ExhaustionTick = {} } } }
''')
L.execute("ns.LOCALE = 'frFR'")
L.eval("function(s) local f = assert(loadstring(s, 'loc')); f('ClaraComboPoints', ClaraNS) end")(loc)
L.eval("function(s) local f = assert(loadstring(s, 'RestedTip.lua')); f('ClaraComboPoints', ClaraNS) end")(src)
res = L.execute(r'''
local fails = 0
local function check(c, m) print((c and "  ok   " or "  FAIL ") .. m) if not c then fails = fails + 1 end end
hooks.login()
check(ns.db.xpTipRested == true and ClaraNS.sv.cuiRestedOn, "on by default: put on once")
hooks.enter()
print("  " .. lines[2]:gsub("\n", " / "))
check(lines[2]:find("^Rested  xp : 1600 %- 10%%\n") ~= nil, "on the rest line, after its name: Rested  xp : 1600 - 10%")
hooks.enter()
check(select(2, lines[2]:gsub("xp :", "")) == 1, "hovered again: written once")
ns.db.xpTipRested = false; ClaraNS.sv.cuiRestedOn = true
lines[2] = "Rested\n200% of normal experience gained from monsters."
hooks.login(); hooks.enter()
check(lines[2]:find("xp :", 1, true) == nil, "turned off by the player afterwards: kept off")
return fails
''')
print(f"{res} failure(s)")
