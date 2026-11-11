import sys
from lupa.lua51 import LuaRuntime
L = LuaRuntime(unpack_returned_tuples=True)
src = open(sys.argv[1], encoding='utf-8').read()
L.execute(r'''
-- the game's picker as this client has it (Mainline): "opacity" is the alpha; while it is set up it calls back with
-- the last picker's alpha still in it
cp = { r = 1, g = 1, b = 1, a = 0.3 }
ColorPickerFrame = { Content = { ColorPicker = {} } }
function ColorPickerFrame:SetupColorPickerAndShow(info)
  self.swatchFunc, self.opacityFunc, self.cancelFunc = info.swatchFunc, info.opacityFunc, info.cancelFunc
  cp.r, cp.g, cp.b = info.r, info.g, info.b
  self.swatchFunc(); self.opacityFunc() -- (stale alpha)
  cp.a = info.opacity
end
function ColorPickerFrame:GetColorRGB() return cp.r, cp.g, cp.b end
function ColorPickerFrame:GetColorAlpha() return cp.a end
E = { env = _G, data = { localization_table = {} } }
ClaraNS = { WST = E }
''')
L.eval("function(s) local f = assert(loadstring(s, 'Config.lua')); f('ClaraComboPoints', ClaraNS) end")(src)
res = L.execute(r'''
local fails = 0
local function check(c, m) print((c and "  ok   " or "  FAIL ") .. m) if not c then fails = fails + 1 end end
local Show = E.data.config.ShowColorPicker
local tex = { SetColorTexture = function(self, r, g, b, a) self.a = a end }
local s = { cooldown_r = 1, cooldown_g = .41, cooldown_b = .71, cooldown_a = 1 }
local changes = 0
for i = 1, 4 do
  Show(s, "cooldown", tex, function() changes = changes + 1 end)
  cp.r, cp.g, cp.b = 0.1 * i, 0.2, 0.3 -- (a new colour picked, the alpha untouched)
  ColorPickerFrame.swatchFunc()
  check(s.cooldown_a == 1, "change " .. i .. ": the bar's alpha stays 1 (" .. tostring(s.cooldown_a) .. ")")
end
s.cooldown_a = 0
Show(s, "cooldown", tex)
check(cp.a == 1, "a colour left invisible by the old turn-over: opened at full alpha")
return fails
''')
print(f"{res} failure(s)")
