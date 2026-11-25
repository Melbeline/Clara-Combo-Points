-- A quest shared from the chat (QuestShare.lua) in the harness: the filter on a "Quest accepted" line, the pad over a
-- link (the real chat window, world map and secure templates), its clicks run: no error. test146 checks the rest.
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
check(ns.QuestShareFilter ~= nil, "loaded")
local ok, e = pcall(ns.QuestShareFilter, env.ChatFrame1, "CHAT_MSG_SYSTEM", "Quest accepted: Nothing Here")
check(ok, "a line filtered: no error " .. tostring(e or ""))
local enter = env.ChatFrame1 and env.ChatFrame1:GetScript("OnHyperlinkEnter")
print("scenario: the chat window's link hook " .. tostring(enter ~= nil))
if enter then
  ok, e = pcall(enter, env.ChatFrame1, "addon:ClaraComboPoints:qshare:share:1105")
  check(ok, "over a bubble: no error " .. tostring(e or ""))
  local pad = rawget(env, "ClaraQuestSharePad")
  if pad then
    ok, e = pcall(pad:GetScript("PreClick"), pad, "LeftButton")
    check(ok, "a left click (not in a group here): no error " .. tostring(e or ""))
    ok, e = pcall(pad:GetScript("PostClick"), pad, "LeftButton")
    check(ok, "after it: no error " .. tostring(e or ""))
  end
end
print("scenario: questshare failures " .. fails)
