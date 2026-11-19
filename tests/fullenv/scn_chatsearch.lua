-- The chat searched, in the game's own chat and menu code: the General tab's menu opened as a right-click opens it
-- (the box put in it), a search in ChatFrame1's real lines (its scroll), no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local frame = rawget(env, "ChatFrame1")
local tab = rawget(env, "ChatFrame1Tab")
check(frame ~= nil and ns.ChatSearch ~= nil, "ChatFrame1 and the search")
if frame and frame.AddMessage then
  for i = 1, 60 do frame:AddMessage("|cffffff00[2. Trade]|r |Hplayer:Lola Moon|h[Lola Moon]|h: line " .. i) end
  frame:AddMessage("|cff00ff00You create: |cff1eff00|Hitem:15095|h[Nightscape Pants]|h|r.|r")
  for i = 61, 80 do frame:AddMessage("|cffffff00[2. Trade]|r |Hplayer:Lola Moon|h[Lola Moon]|h: line " .. i) end
  if (frame:GetNumMessages() or 0) == 0 then
    print("scenario: the harness's chat window keeps no lines (a stand-in): the search's lines checked in test125")
    local ok = pcall(ns.ChatSearch.Typed, frame, "nightscape pants")
    check(ok, "a search in it: no error")
    print("scenario: chat search failures " .. fails)
    return
  end
  local ok, s = pcall(ns.ChatSearch.Typed, frame, "nightscape pants")
  check(ok and s and #s.matches == 1, "one match " .. tostring(ok and #s.matches or s))
  local offset = frame.GetScrollOffset and frame:GetScrollOffset()
  print("scenario: offset after the search " .. tostring(offset) .. " of " .. tostring(frame:GetNumMessages()))
  check(type(offset) == "number" and offset > 0, "the window scrolled up to it")
  ok = pcall(ns.ChatSearch.Typed, frame, "")
  check(ok and (frame:GetScrollOffset() or 0) == 0, "emptied: at its bottom")
end
if tab and rawget(env, "FCF_Tab_SetupMenu") then
  local ok, e = pcall(env.FCF_Tab_SetupMenu, tab)
  check(ok, "the General tab's menu opened " .. tostring(e or ""))
end
print("scenario: chat search failures " .. fails)
