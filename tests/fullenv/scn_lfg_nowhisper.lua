-- LFG Forever without its auto-whispers, in the harness: the window opened, its arrow and Search Again clicked, its
-- settings page built (the harness builds every page), no chat message sent; the removed functions and saved keys gone.
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local LFGF = ns.LFGForeverPrivate
check(LFGF ~= nil, "LFG Forever built in")
if LFGF then
  check(LFGF.AskToJoinMessage == nil and LFGF.InviteWhisperMessage == nil and LFGF.Whisper == nil
    and LFGF.LoadTalentPoints == nil and LFGF.SetInviteActivitySource == nil, "the whisper functions gone")
  local sent = 0
  local chat = rawget(env, "C_ChatInfo")
  local oldSend = chat and chat.SendChatMessage
  if chat then chat.SendChatMessage = function(...) sent = sent + 1 return oldSend and oldSend(...) end end
  local oldSay = rawget(env, "SendChatMessage")
  rawset(env, "SendChatMessage", function(...) sent = sent + 1 if oldSay then return oldSay(...) end end)
  local ok, e = pcall(function()
    env.SlashCmdList.LFGFOREVER("")
    local frame = env.LFGForeverFrame
    if frame and frame.FiltersToggle then
      frame.FiltersToggle:GetScript("OnClick")(frame.FiltersToggle)
      frame.FiltersSearch:GetScript("OnClick")(frame.FiltersSearch)
    end
  end)
  check(ok, "window opened, arrow and Search Again: no error " .. tostring(e or ""))
  check(sent == 0, "no chat message sent (" .. sent .. ")")
  if chat then chat.SendChatMessage = oldSend end
  rawset(env, "SendChatMessage", oldSay)
  local account, character = rawget(env, "ClaraLFGForeverDB"), rawget(env, "ClaraLFGForeverCharDB")
  local left = {}
  for _, t in ipairs({ account or {}, character or {} }) do
    for _, k in ipairs(LFGF.REMOVED_KEYS or {}) do if t[k] ~= nil then left[#left + 1] = k end end
  end
  check(#left == 0, "no removed key in the saved tables " .. table.concat(left, ","))
end
print("scenario: lfg_nowhisper failures " .. fails)
