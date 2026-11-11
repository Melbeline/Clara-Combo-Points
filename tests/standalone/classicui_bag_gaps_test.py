# ClassicUI bag windows: rings touch the neighbour (stack gap 0, column 4 in), the client's gaps when our skin is off.
# usage: python t.py <Modules/ClassicUI folder>
import re, sys
from lupa.lua51 import LuaRuntime
cui = sys.argv[1]
bags = open(cui + '/Windows/Bags.lua', encoding='utf-8').read()
watch = open(cui + '/Bar/BandWatch.lua', encoding='utf-8').read()
m = re.search(r'\nlocal function WrapOpenBags\(shown\)\n.*?\nend\n', watch, re.S)
assert m, 'WrapOpenBags not found'
wrap_src = 'local ns = ...\n' + m.group(0) + '\nreturn WrapOpenBags\n'
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
SCREEN_W, SCREEN_H = 1920, 800
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
local Frame = {}
Frame.__index = Frame
function NewFrame(w, h, opts)
  local f = setmetatable({ w = w, h = h, shown = false, points = {} }, Frame)
  for k, v in pairs(opts or {}) do f[k] = v end
  return f
end
UIParent = NewFrame(SCREEN_W, SCREEN_H, { shown = true })
function Frame:IsShown() return self.shown end
function Frame:GetParent() return UIParent end
function Frame:GetNumPoints() return #self.points end
function Frame:GetPoint(i) local p = self.points[i] if p then return p[1], p[2], p[3], p[4], p[5] end end
function Frame:SetPoint(p, rel, rp, x, y)
  for _, q in ipairs(self.points) do if q[1] == p then q[2], q[3], q[4], q[5] = rel, rp, x or 0, y or 0 return end end
  table.insert(self.points, { p, rel, rp, x or 0, y or 0 })
end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetScale(s) self.scale = s end
function Frame:GetScale() return 1 end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetWidth() return self.w end
function Frame:GetHeight() return self.h end
function Frame:HookScript() end
function Frame:IsCombinedBagContainer() return false end
-- Edges from the one BOTTOMRIGHT anchor every bag window carries.
function Frame:Rect()
  if self == UIParent then return 0, SCREEN_W, 0, SCREEN_H end
  local p, rel, rp, x, y = self:GetPoint(1)
  assert(p == "BOTTOMRIGHT", "bottomright anchors only")
  local rl, rr, rb, rt = rel:Rect()
  local ax = (rp == "BOTTOMRIGHT" or rp == "TOPRIGHT") and rr or rl
  local ay = (rp == "TOPRIGHT") and rt or rb
  local right, bottom = ax + x, ay + y
  return right - self.w, right, bottom, bottom + self.h
end
function Frame:GetRight() return select(2, self:Rect()) end
function Frame:GetBottom() return select(3, self:Rect()) end
function Frame:GetTop() return select(4, self:Rect()) end
-- The backpack (its sheet's ring 1 below its top), three bags (their ring on their top), the key ring.
ContainerFrame1 = NewFrame(192, 240, { shown = true, ringTop = 1 })
ContainerFrame2 = NewFrame(192, 136, { shown = true, ringTop = 0 })
ContainerFrame3 = NewFrame(192, 136, { shown = true, ringTop = 0 })
ContainerFrame4 = NewFrame(192, 177, { shown = true, ringTop = 0 })
ContainerFrame5 = NewFrame(192, 136, { shown = true, ringTop = 0 })
order = { ContainerFrame1, ContainerFrame2, ContainerFrame3, ContainerFrame4, ContainerFrame5 }
CONTAINER_OFFSET_Y = 85
-- The client's pass, as ContainerFrame.lua lays it (scale 1).
function UpdateContainerFrameAnchors()
  local yOffset = CONTAINER_OFFSET_Y
  local freeScreenHeight = SCREEN_H - yOffset
  local previousBag, firstBagInMostRecentColumn
  for index, frame in ipairs(order) do
    frame:ClearAllPoints()
    if index == 1 then
      frame:SetPoint("BOTTOMRIGHT", frame:GetParent(), "BOTTOMRIGHT", 0, yOffset)
      firstBagInMostRecentColumn = frame
    elseif (freeScreenHeight < frame:GetHeight()) or previousBag:IsCombinedBagContainer() then
      freeScreenHeight = SCREEN_H - yOffset
      frame:SetPoint("BOTTOMRIGHT", firstBagInMostRecentColumn, "BOTTOMLEFT", -11, 0)
      firstBagInMostRecentColumn = frame
    else
      frame:SetPoint("BOTTOMRIGHT", previousBag, "TOPRIGHT", 0, 8)
    end
    previousBag = frame
    freeScreenHeight = freeScreenHeight - frame:GetHeight()
  end
end
function hooksecurefunc(name, fn)
  local orig = _G[name]
  hookCount = (hookCount or 0) + 1
  _G[name] = function(...) local r = orig(...) fn(...) return r end
end
function InCombatLockdown() return false end
Enum = { BagIndex = { Keyring = -2, Backpack = 0, ReagentBag = 5 } }
modules = {}
ns = setmetatable({ EMPTY = {}, bags = { NewBand = function() end, ownChildren = {} }, db = {} }, { __index = function(_, k)
  if type(k) == "string" and k:match("^%u") and k ~= k:upper() then return function() end end
end })
function ns.RegisterModule(name, mod) modules[name] = mod end
function ns.SafeCall(fn, ...) return pcall(fn, ...) end
function ns.SetPointOnce(f, ...) f:SetPoint(...) end
function ns.BagIsParked() return false end
ClaraNS = { ClassicUIRuns = true, ClassicUIPrivate = ns }
''')
L.eval("function(s) local f = assert(loadstring(s, 'Bags.lua')); f('ClaraComboPoints', ClaraNS) end")(bags)
L.eval("function(s) WrapOpenBags = assert(loadstring(s, 'WrapOpenBags'))(ns) end")(wrap_src)
res = L.execute(r'''
local fails = 0
local function check(c, m) print((c and "  ok   " or "  FAIL ") .. m) if not c then fails = fails + 1 end end
local function anchor(f) local _, rel, rp, x, y = f:GetPoint(1) return rel, rp, x, y end
local function gaps()
  -- stack: the lower window's ring top to the upper window's lip; column: the key ring's art (2 inside its right)
  -- to the backpack's ring (2 inside its left).
  local _, _, _, top1 = ContainerFrame1:Rect()
  local _, _, b2 = ContainerFrame2:Rect()
  local _, _, _, top2 = ContainerFrame2:Rect()
  local _, _, b3 = ContainerFrame3:Rect()
  local _, r5 = ContainerFrame5:Rect()
  local l1 = ContainerFrame1:Rect()
  return b2 - (top1 - ContainerFrame1.ringTop), b3 - (top2 - ContainerFrame2.ringTop), (l1 + 2) - (r5 - 2)
end
UpdateContainerFrameAnchors()
local x, y = ns.BagGaps()
check(x == 8 and y == -11, "skin off: the client's gaps (8, -11)")
local _, rp5, x5 = anchor(ContainerFrame5)
check(rp5 == "BOTTOMLEFT" and x5 == -11, "the client's pass starts a column for the key ring")
local s1, s2, c = gaps()
print(string.format("  client: stack %d, %d  column %d", s1, s2, c))
modules.bags.apply()
check(hookCount == 1, "one hook on the client's pass")
local s1, s2, c = gaps()
print(string.format("  ours:   stack %d, %d  column %d", s1, s2, c))
check(s1 == 1 and s2 == 0 and c == 0, "applied: rings touch the window above (backpack's 1 under its top) and the key ring's art")
check(select(4, anchor(ContainerFrame2)) == 0 and select(3, anchor(ContainerFrame5)) == 4, "anchors: stack 0, column 4")
UpdateContainerFrameAnchors()
local s1, s2, c = gaps()
check(s1 == 1 and s2 == 0 and c == 0, "the client's next pass (a bag opened) gets our gaps again")
modules.bags.apply()
check(hookCount == 1, "applied again: still one hook")
-- A window placed by something else keeps its spot.
ContainerFrame3:ClearAllPoints()
ContainerFrame3:SetPoint("BOTTOMRIGHT", UIParent, "TOPRIGHT", 0, 8)
ContainerFrame4:ClearAllPoints()
ContainerFrame4:SetPoint("BOTTOMRIGHT", ContainerFrame2, "TOPRIGHT", 0, 20)
-- applied again (an option pass): only the client's own anchors move
modules.bags.apply()
local rel3, rp3, x3, y3 = anchor(ContainerFrame3)
check(rel3 == UIParent and y3 == 8, "anchored to the screen with the client's 8: untouched")
check(select(4, anchor(ContainerFrame4)) == 20, "another gap set by hand: untouched")
-- The band watcher's per-frame layout (ClassicUI bars on) uses the same gaps.
UpdateContainerFrameAnchors()
WrapOpenBags(order)
local s1, s2, c = gaps()
check(s1 == 1 and s2 == 0 and c == 0, "band watcher: same gaps as the hook")
-- 85 + 240 + 136 + 136 + 177 = 774 of 800: a window 20 tall fits on the column only without the client's three 8s.
ContainerFrame5.h = 20
WrapOpenBags(order)
local _, rp5 = anchor(ContainerFrame5)
check(rp5 == "TOPRIGHT", "band watcher: a window that fits only without the client's 8s stays in the column")
modules.bags.restore()
local x, y = ns.BagGaps()
check(x == 8 and y == -11, "skin off again: the client's gaps")
WrapOpenBags(order)
local _, rp5, x5 = anchor(ContainerFrame5)
check(rp5 == "BOTTOMLEFT" and x5 == -11, "band watcher with the client's gaps: the tall one starts a column again")
ContainerFrame5.h = 136
UpdateContainerFrameAnchors()
local s1, s2, c = gaps()
check(s1 == 9 and s2 == 8, "skin off: the hook leaves the client's pass alone")
return fails
''')
print(f"{res} failure(s)")
sys.exit(1 if res else 0)
