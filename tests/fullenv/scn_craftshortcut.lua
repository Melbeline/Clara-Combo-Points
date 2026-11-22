-- A recipe on the action bars (CraftShortcut.lua) in the harness: the game's own output button template made draggable,
-- a drag, a click of the shortcut, its tooltip: no error. (The harness makes no ProfessionsFrame: test144 runs the rest.)
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
check(type(rawget(env, "ClaraCraft")) == "function" and ns.CraftShortcut ~= nil and ns.CraftShortcutDragFrom ~= nil, "loaded")
local ok, button = pcall(env.CreateFrame, "Button", nil, env.UIParent, "ProfessionsOutputButtonTemplate")
print("scenario: the game's output button " .. tostring(ok and button ~= nil))
if ok and button then
  local e
  ok, e = pcall(ns.CraftShortcutDragFrom, button, function() return 17187 end)
  check(ok, "made draggable " .. tostring(e or ""))
  local drag = button:GetScript("OnDragStart")
  check(drag ~= nil, "its drag hooked")
  if drag then ok, e = pcall(drag, button); check(ok, "dragged: no error " .. tostring(e or "")) end
end
local e
ok, e = pcall(env.ClaraCraft, 17187)
check(ok, "the shortcut clicked: no error " .. tostring(e or ""))
ok, e = pcall(ns.CraftShortcutTip, env.GameTooltip, 1)
check(ok, "its tooltip: no error " .. tostring(e or ""))
print("scenario: craftshortcut failures " .. fails)
