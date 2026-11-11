import sys
from lupa.lua51 import LuaRuntime
L = LuaRuntime(unpack_returned_tuples=True)
src = open(sys.argv[1], encoding='utf-8').read()
L.execute(r'''
combat = false
function InCombatLockdown() return combat end
Enum = { TraitConfigType = { Combat = 1, Profession = 2, Generic = 3, CamelotCombat = 9 } }
configs = { [10] = { type = 9 }, [20] = { type = 3 } }
can = { change = false, add = false, why = "You can't change talents in combat." }
edit = { ok = false, why = "Not now." }
C_Traits = { GetConfigInfo = function(id) return configs[id] end, CanEditConfig = function(id) return edit.ok, edit.why end }
C_ClassTalents = { CanChangeTalents = function() return can.change, can.add, can.why end }
ns = setmetatable({ L = {} }, { __index = function() return function() end end })
ClaraNS = { ClassicUIRuns = true, ClassicUIPrivate = ns }
''')
L.eval("function(s) local f = assert(loadstring(s, 'TalentWindow.lua')); pcall(f, 'ClaraComboPoints', ClaraNS) end")(src)
res = L.execute(r'''
local fails = 0
local function check(c, m) print((c and "  ok   " or "  FAIL ") .. m) if not c then fails = fails + 1 end end
local May = rawget(ns, "TalentsMayApply")
check(type(May) == "function", "the game's rule for Apply is there")
check(May({ configID = 10 }) == true, "out of a fight: as before")
combat = true
local ok, why = May({ configID = 10 })
check(ok == false and why == can.why, "in a fight, the game says no: no, with its own reason")
can.add = true
check(May({ configID = 10 }) == true, "in a fight, new points only (a level gained): the game says yes, applied")
can.add, can.change = false, true
check(May({ configID = 10 }) == true, "the game says it can change: applied")
check(May({ configID = 20 }) == false, "the Legacy tree: its own rule (C_Traits.CanEditConfig), no")
edit.ok = true
check(May({ configID = 20 }) == true, "the Legacy tree, the game allowing: applied")
return fails
''')
print(f"{res} failure(s)")
