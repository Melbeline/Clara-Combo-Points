-- The chat channels (ChatPlace.lua, UnitScan.lua): UnitScan's hidden channel joined once the channels have settled
-- (the last number), never in the player's kept order, put after the player's own; a colour picked kept by name and
-- put back when the game gives the number's colour again; no colour picked: the default
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 100 do M.RunTimer() n = n + 1 end end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = {} }
for _, k in ipairs({ "lfgforever", "whatstraining", "doesitdie", "enhancedraidframes", "buyemall", "leatrix", "nodesight", "wst",
  "dynamiccam", "dialogkey", "xtolevel", "minimapdrawer", "mail", "classicui", "tullarange", "names", "tooltipanchor", "idtip",
  "soloraidframe", "enemycasts", "reverseengineering", "fishing" }) do ClaraComboPointsDB.qol[k] = false end
ChatTypeInfo = setmetatable({}, { __index = function(t, k) local v = { r = 1, g = 1, b = 1 } rawset(t, k, v) return v end })
local function Color(i) local c = ChatTypeInfo["CHANNEL" .. i] return string.format("%.2f %.2f %.2f", c.r, c.g, c.b) end
function ChangeChatColor(chatType, r, g, b)
  local c = ChatTypeInfo[chatType] c.r, c.g, c.b = r, g, b
  M.Fire("UPDATE_CHAT_COLOR", chatType, r, g, b)
end
C_ChatInfo.SwapChatChannelsByChannelIndex = function(a, b)
  S.channels[a], S.channels[b] = S.channels[b], S.channels[a]
  local ca, cb = ChatTypeInfo["CHANNEL" .. a], ChatTypeInfo["CHANNEL" .. b] -- (the game: colours stay with the numbers)
end
ChatConfigFrame = CreateFrame("Frame", "ChatConfigFrame", UIParent); ChatConfigFrame:Hide()

S.channels = { "General - Elwynn Forest" }
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.now = 100
M.Fire("PLAYER_ENTERING_WORLD", true, false)
for _ = 1, 20 do if M.timers and #M.timers > 0 then M.RunTimer() end end -- (a few seconds' worth)
check(#M.joined == 0, "the channels not settled yet: UnitScan's channel not joined")
-- the server rejoins the player's channels meanwhile
table.insert(S.channels, "Trade - City"); M.Fire("CHANNEL_UI_UPDATE")
table.insert(S.channels, "L2P"); M.now = 103; M.Fire("CHANNEL_UI_UPDATE")
M.now = 115
for _ = 1, 12 do Run() end
check(M.joined[1] == "ushccomms", "settled: UnitScan's channel joined now, after them (" .. tostring(M.joined[1]) .. ")")
table.insert(S.channels, "ushccomms"); M.Fire("CHANNEL_UI_UPDATE"); Run()

out("== the order")
-- the player drags L2P first
C_ChatInfo.SwapChatChannelsByChannelIndex(1, 3); Run()
M.Fire("PLAYER_LOGOUT")
local order = table.concat(ClaraComboPointsDB.chatChannels.order, ",")
check(not order:find("ushccomms"), "the hidden channel never in the player's order (" .. order .. ")")
-- next login: ushccomms rejoined early by the server, second
S.channels = { "General - Elwynn Forest", "ushccomms", "Trade - City", "L2P" }
M.now = 150; ns.ChatChannels.Apply()
for _ = 1, 8 do M.Fire("CHANNEL_UI_UPDATE"); Run() end
for i = 1, 8 do ns.ChatChannels.Apply() end
check(S.channels[#S.channels] == "ushccomms", "the hidden channel put after the player's own: " .. table.concat(S.channels, ", "))

out("== the colours")
M.now = 400 -- (past the minutes after login: the order no longer put back, only the colours)
S.channels = { "General - Elwynn Forest", "Trade - City", "L2P" }
ns.ChatChannels.Apply(); Run()
check(Color(2) == "1.00 0.75 0.75", "no colour picked: the default (FFC0C0) (" .. Color(2) .. ")")
ChatConfigFrame:Show()
ChangeChatColor("CHANNEL2", 0, 1, 0); Run()
ChatConfigFrame:Hide()
check(ClaraComboPointsDB.chatChannels.colors["trade"] ~= nil, "a colour picked in the chat settings: kept for the channel's name")
-- the game puts the number's former colour back
ChatTypeInfo.CHANNEL2.r, ChatTypeInfo.CHANNEL2.g, ChatTypeInfo.CHANNEL2.b = 1, .75, .75
M.Fire("UPDATE_CHAT_COLOR", "CHANNEL2", 1, .75, .75); Run()
check(Color(2) == "0.00 1.00 0.00", "the game gave the number's colour again: the channel's own back (" .. Color(2) .. ")")
-- Trade moves to number 3: its colour follows it
C_ChatInfo.SwapChatChannelsByChannelIndex(2, 3); Run(); ns.ChatChannels.Apply(); Run()
check(Color(3) == "0.00 1.00 0.00" and Color(2) == "0.00 0.66 1.00", "a channel moved: its colour with it, L2P's own where it went (" .. Color(3) .. " / " .. Color(2) .. ")")
out(string.format("\n%d failure(s)", fails))
return fails
