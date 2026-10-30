-- The character window's equipment flyout (Flyout.lua) over stand-ins (lupa, Lua 5.1).
local ADDON = ...
local function readfile(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local fails = 0
local function check(c, m) print((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local function Region(name)
  local r = { name = name, shown = true, w = 37, h = 37 }
  function r:ClearAllPoints() self.points = {} end
  function r:SetPoint(p, rel, rp, x, y) self.points = self.points or {}; self.points[#self.points + 1] = { p, rel, rp, x or 0, y or 0 } end
  function r:IsShown() return self.shown end
  function r:GetWidth() return self.w end
  function r:GetHeight() return self.h end
  return r
end
local env = setmetatable({}, { __index = _G })
env._G = env
local refreshed = {}
env.EquipmentFlyoutPopoutButton_RefreshVisualState = function(arrow) refreshed[arrow] = arrow:GetParent().flyoutDirection end
env.EQUIPMENTFLYOUT_BORDERWIDTH = 3
local names = { "CharacterHeadSlot", "CharacterWristSlot", "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
  "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot",
  "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot" }
for _, n in ipairs(names) do
  local slot = Region(n)
  slot.flyoutDirection = n:find("Main") or n:find("Secondary") or n:find("Ranged") and "UP" or (n:find("Head") or n:find("Wrist")) and "RIGHT" or "LEFT"
  if n:find("MainHand") or n:find("SecondaryHand") or n:find("Ranged") then slot.flyoutDirection = "UP" end
  local arrow = Region(n .. "PopoutButton")
  arrow.w, arrow.h = 16, 32
  arrow.GetParent = function() return slot end
  slot.popoutButton = arrow
  env[n] = slot
end
local flyout = { buttonFrame = Region("buttonFrame") }
env.EquipmentFlyoutFrame = flyout
-- the game's layout: from the arrow (as EquipmentFlyout_UpdateItems)
env.EquipmentFlyout_UpdateItems = function()
  local frame, slot = flyout.buttonFrame, flyout.button
  frame:ClearAllPoints()
  local rel = slot.popoutButton or slot
  if slot.flyoutDirection == "LEFT" then frame:SetPoint("TOPRIGHT", rel, "TOPLEFT", 0, -3)
  elseif slot.flyoutDirection == "UP" then frame:SetPoint("BOTTOMLEFT", rel, "TOPLEFT", 0, 0)
  elseif slot.flyoutDirection == "DOWN" then frame:SetPoint("TOPLEFT", rel, "BOTTOMLEFT", 0, 0)
  else frame:SetPoint("TOPLEFT", rel, "TOPRIGHT", 0, -3) end
end
env.hooksecurefunc = function(name, hook)
  local orig = env[name]
  env[name] = function(...) local r = orig(...) hook(...) return r end
end
local frames = {}
env.CreateFrame = function()
  local f = { events = {} }
  function f:RegisterEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:SetScript(_, fn) self.onEvent = fn end
  frames[#frames + 1] = f
  return f
end
local fn = assert(loadstring(readfile(ADDON .. "/Flyout.lua"), "@Flyout.lua"))
setfenv(fn, env)
fn("ClaraComboPoints", {})
for _, f in ipairs(frames) do if f.events.PLAYER_LOGIN then f.onEvent(f, "PLAYER_LOGIN") end end

local function Point(r) return r.points and r.points[1] end
local function Show(name)
  flyout.button = env[name]
  env.EquipmentFlyout_UpdateItems()
  return Point(flyout.buttonFrame)
end

print("== the slots turned")
check(env.CharacterHandsSlot.flyoutDirection == "RIGHT" and env.CharacterTrinket1Slot.flyoutDirection == "RIGHT", "the right column: to the right")
check(env.CharacterMainHandSlot.flyoutDirection == "DOWN" and env.CharacterRangedSlot.flyoutDirection == "DOWN", "the weapons: down")
check(env.CharacterHeadSlot.flyoutDirection == "RIGHT" and not env.CharacterHeadSlot.popoutButton.points, "the left column: left as the game has it")
local a = Point(env.CharacterFinger1Slot.popoutButton)
check(a and a[1] == "LEFT" and a[2] == env.CharacterFinger1Slot and a[3] == "RIGHT" and a[4] == 5, "a ring's arrow: on its right")
a = Point(env.CharacterSecondaryHandSlot.popoutButton)
check(a and a[1] == "TOP" and a[3] == "BOTTOM" and a[5] == -5, "the off hand's arrow: under it")
check(refreshed[env.CharacterFinger1Slot.popoutButton] == "RIGHT" and refreshed[env.CharacterRangedSlot.popoutButton] == "DOWN", "the arrows pointing the new way")

print("== the flyout, Alt over a slot (the arrows hidden)")
for _, n in ipairs(names) do env[n].popoutButton.shown = false end
local p = Show("CharacterMainHandSlot")
check(p and p[1] == "TOPLEFT" and p[2] == env.CharacterMainHandSlot and p[3] == "BOTTOMLEFT" and p[4] == -3 and p[5] == -2,
  "main hand: under it, its first button's left on the slot's (the frame's border 3 to the left)")
p = Show("CharacterSecondaryHandSlot")
check(p and p[2] == env.CharacterSecondaryHandSlot and p[3] == "BOTTOMLEFT" and p[4] == -3, "off hand: under it, the same way")
p = Show("CharacterRangedSlot")
check(p and p[2] == env.CharacterRangedSlot and p[3] == "BOTTOMLEFT", "ranged: under it")
p = Show("CharacterFinger1Slot")
check(p and p[1] == "TOPLEFT" and p[2] == env.CharacterFinger1Slot and p[3] == "TOPRIGHT" and p[4] == 2 and p[5] == 3,
  "ring 2: to its right, its first button's top on the slot's")
p = Show("CharacterHandsSlot")
check(p and p[2] == env.CharacterHandsSlot and p[3] == "TOPRIGHT", "hands: to its right")
p = Show("CharacterHeadSlot")
check(p and p[1] == "TOPLEFT" and p[2] == env.CharacterHeadSlot.popoutButton and p[3] == "TOPRIGHT", "head (left column): the game's own")

print("== the equipment manager open (the arrows shown)")
for _, n in ipairs(names) do env[n].popoutButton.shown = true end
p = Show("CharacterMainHandSlot")
check(p and p[4] == -3 and p[5] == -(5 + 32 + 2), "main hand: under its arrow")
p = Show("CharacterTrinket0Slot")
check(p and p[4] == 5 + 16 + 2 and p[5] == 3, "trinket: right of its arrow, level with the slot")

print("")
print(fails .. " failure(s)")
