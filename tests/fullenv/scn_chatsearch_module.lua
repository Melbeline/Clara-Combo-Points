-- The chat search as a module, with the harness's frames: its page built, each style picked (the game's chat window
-- searched and drawn again each time), its place's box: no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
check(ns:QolRuns("chatsearch") and ns.ChatSearch ~= nil, "the module runs")
check(ns.chatSearchCategory ~= nil, "its page registered in the game's options")
local page = ns.ChatSearchPage
if page then
  local ok, e = pcall(function() page:Show(); page:GetScript("OnShow")(page) end)
  check(ok, "its page built " .. tostring(e or ""))
end
local frame = rawget(env, "ChatFrame1")
if frame and ns.ChatSearch then
  for i = 1, 30 do frame:AddMessage("line " .. i .. " Charlotte says hello") end
  for _, style in ipairs(ns.CHATSEARCH_STYLES) do
    local ok, e = pcall(function()
      ns:SetChatSearchStyle(style)
      ns.ChatSearch.Typed(frame, "charlotte")
      ns.ChatSearch.Step(frame, 1)
      if frame.RefreshDisplay then frame:RefreshDisplay() end
      ns.ChatSearch.Marks.Show(frame)
    end)
    check(ok, "style " .. style .. ": searched, drawn again " .. tostring(e or ""))
  end
  local ok, e = pcall(ns.ChatSearch.Typed, frame, "")
  check(ok, "emptied " .. tostring(e or ""))
  ns:SetChatSearchStyle("E")
end
local ok, e = pcall(function() ns:SetChatSearchDock(false); ns:SetChatSearchDock(true) end)
check(ok, "its place's box both ways " .. tostring(e or ""))
print("scenario: chat search module failures " .. fails)
