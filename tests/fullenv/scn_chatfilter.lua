-- The chat blacklist's window in the full harness: built with the game's templates (its inset, its box with a hint,
-- its slider), a word added and shown, its time set, its corner, its button; nothing failing.
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
check(type(ns.ChatFilterOpen) == "function", "the blacklist runs")
if ns.ChatFilterOpen then
  local ok, e = pcall(ns.ChatFilterOpen)
  check(ok, "its window opens: " .. tostring(e))
  local win = env.ClaraChatFilter
  if win and not win:IsShown() then ns.ChatFilterOpen() end -- (opened already by the harness's own clicks: closed by this one)
  check(win and win:IsShown(), "shown")
  if win then
    check(win.inset ~= nil and win.box ~= nil and win.slider ~= nil and win.grip ~= nil, "its inset, its box, its slider, its corner")
    ok, e = pcall(function() ns.ChatFilterAdd("boost") ns.ChatFilterAdd("{rt8} wts", false, true) end)
    check(ok, "words added: " .. tostring(e))
    check(win.rows[1] and win.rows[1]:IsShown() and win.rows[2] and win.rows[2]:IsShown(), "listed")
    check(win.empty and not win.empty:IsShown(), "the empty list's line hidden")
    ok, e = pcall(function() win.slider:GetScript("OnValueChanged")(win.slider, 300) end)
    check(ok and ns.ChatFilterStore().repeatSeconds == 300, "its slider: " .. tostring(e))
    ok, e = pcall(function() win.unit:GetScript("OnClick")(win.unit) end)
    check(ok, "its unit's button: " .. tostring(e))
    ok, e = pcall(function() win:Hide() win:Show() end)
    check(ok, "shown again: " .. tostring(e))
  end
end
print("scenario: chatfilter failures " .. fails)
