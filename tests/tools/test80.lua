-- The chat channels (ChatPlace.lua, UnitScan.lua): UnitScan's hidden channel joined once the channels have settled
-- (the last number); the channels' order and colours the game's own: Clara never moves nor recolours one (no swap, no
-- colour of its own, none put back), and forgets what it kept before
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 100 do M.RunTimer() n = n + 1 end end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = {}, chatChannels = { order = { "l2p", "general" }, colors = { trade = { 0, 1, 0 } }, v = 2 } }
for _, k in ipairs({ "lfgforever", "whatstraining", "doesitdie", "enhancedraidframes", "buyemall", "leatrix", "nodesight", "wst",
  "dynamiccam", "dialogkey", "xtolevel", "minimapdrawer", "mail", "classicui", "tullarange", "names", "tooltipanchor", "idtip",
  "soloraidframe", "enemycasts", "reverseengineering", "fishing" }) do ClaraComboPointsDB.qol[k] = false end
ChatTypeInfo = setmetatable({}, { __index = function(t, k) local v = { r = 1, g = 1, b = 1 } rawset(t, k, v) return v end })
local function Color(i) local c = ChatTypeInfo["CHANNEL" .. i] return string.format("%.2f %.2f %.2f", c.r, c.g, c.b) end
local colorCalls, swapCalls = 0, 0
function ChangeChatColor(chatType, r, g, b)
  colorCalls = colorCalls + 1
  local c = ChatTypeInfo[chatType] c.r, c.g, c.b = r, g, b
  M.Fire("UPDATE_CHAT_COLOR", chatType, r, g, b)
end
C_ChatInfo.SwapChatChannelsByChannelIndex = function(a, b)
  swapCalls = swapCalls + 1
  S.channels[a], S.channels[b] = S.channels[b], S.channels[a]
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

out("== the order and colours: the game's own")
check(ClaraComboPointsDB.chatChannels == nil, "what Clara kept before (order, colours by name): forgotten")
-- the player drags L2P first, then picks a colour for Trade
C_ChatInfo.SwapChatChannelsByChannelIndex(1, 3); Run()
ChatConfigFrame:Show()
ChangeChatColor("CHANNEL2", 0, 1, 0); Run()
ChatConfigFrame:Hide()
local playerSwaps, playerColors = swapCalls, colorCalls
M.Fire("PLAYER_LOGOUT")
-- next login: the server rejoins them in another order; the game gives a number its former colour
S.channels = { "General - Elwynn Forest", "ushccomms", "Trade - City", "L2P" }
M.now = 150
for _ = 1, 8 do M.Fire("CHANNEL_UI_UPDATE"); Run() end
ChatTypeInfo.CHANNEL2.r, ChatTypeInfo.CHANNEL2.g, ChatTypeInfo.CHANNEL2.b = 1, .75, .75
M.Fire("UPDATE_CHAT_COLOR", "CHANNEL2", 1, .75, .75); Run()
M.Fire("PLAYER_ENTERING_WORLD", false, false); Run()
check(swapCalls == playerSwaps, "no channel moved by Clara (" .. (swapCalls - playerSwaps) .. ")")
check(colorCalls == playerColors and Color(2) == "1.00 0.75 0.75", "no colour put by Clara: the game's stands (" .. Color(2) .. ")")
check(ClaraComboPointsDB.chatChannels == nil, "nothing kept")
out(string.format("\n%d failure(s)", fails))
return fails
