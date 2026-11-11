import sys, lupa
from lupa.lua51 import LuaRuntime
L = LuaRuntime(unpack_returned_tuples=True)
d = sys.argv[1]
L.execute(r'''
fails = 0
function check(c, m) print((c and "  ok   " or "  FAIL ") .. m) if not c then fails = fails + 1 end end
combat = false
function InCombatLockdown() return combat end
function GetLocale() return "frFR" end
UIParent = {}
local registered
Menu = { ModifyMenu = function(tag, fn) registered = registered or {} registered[tag] = fn end }
MenuUtil = {}
MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = 1 } }
function GameTooltip_SetTitle() end function GameTooltip_AddNormalLine() end
function Registered() return registered end
''')
ns = L.eval('{ refresh = {} }')
for f in ['Locales.lua', 'Menu.lua']:
    src = open(f"{d}/EasyFishing/{f}", encoding='utf-8').read()

    fn = L.eval("function(src, name, ns) local f = assert(loadstring(src, name)); return f('EasyFishing', ns) end")
    fn(src, f, ns)
L.globals().ns = ns
res = L.execute(r'''
ns.db = {}
function ns:Mode() return false end
function ns:ModeTip() return "tip" end
local fn = Registered() and Registered().MENU_UNIT_SELF
check(fn ~= nil, "hooked the player's portrait menu")
local GAME = { "Lola", "Set Focus", "Other Options", "Edit Mode", "Leave Party" }
local function Root()
  local r = { items = {} }
  for i, t in ipairs(GAME) do r.items[i] = { text = t } end
  local function add(self, d) table.insert(self.items, d) return d end
  function r:CreateDivider() return add(self, { text = "<divider>" }) end
  function r:CreateTitle(t) return add(self, { text = t }) end
  function r:CreateCheckbox(t) return add(self, { text = t, SetTooltip = function() end }) end
  function r:CreateFrame() return add(self, { text = "<frame>", AddInitializer = function() end, AddResetter = function() end }) end
  function r:Insert() error("the game's list touched") end
  return r
end
local root = Root()
fn(nil, root, {})
local t = {} for i, x in ipairs(root.items) do t[i] = x.text end
print("  " .. table.concat(t, " | "))
local same = true for i, x in ipairs(GAME) do if root.items[i].text ~= x then same = false end end
check(same and root.items[#GAME].text == "Leave Party", "the game's entries as they are")
check(t[#GAME + 1] == "<divider>" and t[#GAME + 2] == "Pêche" and t[#GAME + 3] == "Mode pêche" and t[#GAME + 4] == "<frame>", "the Fishing section after them")
check(rawget(root, "elementDescriptions") == nil, "no list written")
combat = true
local fight = Root()
fn(nil, fight, {})
check(#fight.items == #GAME, "in combat: nothing added")
return fails
''')
print(f"{res} failure(s)")
