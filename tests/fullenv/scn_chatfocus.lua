-- The chat's typing bar kept (ChatFocus.lua) in the harness: loaded, its setting switched off and on, its keeper asked,
-- no error. (The harness does not load the game's chat code, Blizzard_ChatFrameBase: test140 runs the game's own check.)
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
check(ns.ChatFocusKeeper ~= nil and ns.ChatKeepsFocus ~= nil, "loaded")
local ok, e = pcall(function()
  ns:SetChatKeepsFocus(false)
  ns:SetChatKeepsFocus(true)
  return ns.ChatFocusKeeper:HasStickyFocus()
end)
check(ok, "switched off and on, asked: no error " .. tostring(e))
check(ns:ChatKeepsFocus(), "on")
print("scenario: chatfocus failures " .. fails)
