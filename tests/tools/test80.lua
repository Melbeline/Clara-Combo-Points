-- The chat channels (ChatPlace.lua, UnitScan.lua): UnitScan's hidden channel joined once the channels have settled
-- (the last number); the channels' order the game's own (Clara never moves one); each channel's colour kept by the
-- channel, whatever its number: its default (the custom l2p 00A9FF, the community L2P 40FF40, any other FFC0C0), or
-- the one the player picked (kept for the account); given back to the game under the channel's number after a relog
-- that gave the numbers each other's colours, after a swap in Chat settings (the game's swap moves the colours for the
-- session only); the game's Defaults: the picks forgotten; Clara's own colouring never taken for a pick
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
local resets = 0
function ResetChatColors() resets = resets + 1 end -- (the game's Defaults: its own colours back, by number)

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

local function Hexed(i) local c = ChatTypeInfo["CHANNEL" .. i] return string.format("%02X%02X%02X", math.floor(c.r * 255 + .5), math.floor(c.g * 255 + .5), math.floor(c.b * 255 + .5)) end
local function Index(name) for i, n in ipairs(S.channels) do if n == name then return i end end end

out("== each channel's colour: its defaults")
check(ClaraComboPointsDB.chatChannels == nil, "what an earlier Clara kept (order, colours by name): forgotten")
-- the player's channels: the custom l2p, the community L2P, the zone and city ones
S.channels = { "l2p", "Community:4242:1", "General - Elwynn Forest", "Trade - City", "ushccomms" }
ChatFrameUtil = ChatFrameUtil or {}
-- (right after login the game has not the community yet: its channel's name unknown)
ChatFrameUtil.ResolveChannelName = function(name) return name end
local c2 = ChatTypeInfo.CHANNEL2 c2.r, c2.g, c2.b = 1, 1, 1
M.Fire("CHANNEL_UI_UPDATE")
for _ = 1, 3 do Run() end
check(Hexed(2) == "FFFFFF", "the community not loaded yet: its channel left as it is, not given another's default (" .. Hexed(2) .. ")")
ChatFrameUtil.ResolveChannelName = function(name) if name:find("^Community:4242") then return "L2P" end return name end
M.Fire("CLUB_STREAMS_LOADED", 4242); Run()
check(Hexed(1) == "00A9FF", "l2p (custom): 00A9FF (" .. Hexed(1) .. ")")
check(Hexed(2) == "40FF40", "L2P (the community): 40FF40 (" .. Hexed(2) .. ")")
check(Hexed(3) == "FFC0C0" and Hexed(4) == "FFC0C0" and Hexed(5) == "FFC0C0", "the others: FFC0C0")
check(ClaraComboPointsDB.channelColors and next(ClaraComboPointsDB.channelColors) == nil, "Clara's own colouring: not taken for a pick")

out("== a colour picked: kept for that channel")
ChatConfigFrame:Show()
ChangeChatColor("CHANNEL4", 0.2, 0.6, 1); Run() -- (Trade, picked in Chat settings)
ChatConfigFrame:Hide()
check(ClaraComboPointsDB.channelColors.trade and Hexed(4) == "3399FF", "Trade's picked colour kept (" .. Hexed(4) .. ")")

out("== a relog: the channels in other numbers, each number with its former colour")
local swaps = swapCalls
S.channels = { "Trade - City", "General - Elwynn Forest", "ushccomms", "Community:4242:1", "l2p" }
for i = 1, 5 do local c = ChatTypeInfo["CHANNEL" .. i] c.r, c.g, c.b = ({ 0, 0.25, 1, 1, 1 })[i], ({ 0.66, 1, 0.75, 0.75, 0.75 })[i], ({ 1, 0.25, 0.75, 0.75, 0.75 })[i] end
M.now = 200
M.Fire("CHANNEL_UI_UPDATE"); Run()
check(Hexed(Index("l2p")) == "00A9FF" and Hexed(Index("Community:4242:1")) == "40FF40" and Hexed(Index("Trade - City")) == "3399FF"
  and Hexed(Index("General - Elwynn Forest")) == "FFC0C0", "each channel its own colour again, whatever its number")
check(swapCalls == swaps, "no channel moved by Clara")

out("== dragged in Chat settings: the game's swap moves the colours for the session; given to the game again")
local before = colorCalls
ChatConfigFrame:Show()
-- (the game's own: ChatConfigChannelSettings_SwapChannelsByIndex swaps its ChatTypeInfo tables, then the channels)
ChatTypeInfo.CHANNEL1, ChatTypeInfo.CHANNEL2 = ChatTypeInfo.CHANNEL2, ChatTypeInfo.CHANNEL1
C_ChatInfo.SwapChatChannelsByChannelIndex(1, 2); Run()
ChatConfigFrame:Hide()
check(colorCalls - before >= #S.channels, "every channel's colour given to the game again (" .. (colorCalls - before) .. ")")
check(Hexed(Index("Trade - City")) == "3399FF" and Hexed(Index("General - Elwynn Forest")) == "FFC0C0", "the colours with their channels")
check(ClaraComboPointsDB.channelColors.trade and not ClaraComboPointsDB.channelColors.general, "Clara's colouring in Chat settings: not taken for a pick")

out("== the game's Defaults: the picks forgotten")
ResetChatColors(); Run()
check(resets == 1 and next(ClaraComboPointsDB.channelColors) == nil, "the colours picked forgotten")
check(Hexed(Index("Trade - City")) == "FFC0C0" and Hexed(Index("l2p")) == "00A9FF", "the defaults back: Trade FFC0C0, l2p 00A9FF")
out(string.format("\n%d failure(s)", fails))
return fails
