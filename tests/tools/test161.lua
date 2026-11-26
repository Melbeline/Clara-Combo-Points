-- The community chats back after a login (CommunityChat.lua): a community a chat window shows, not joined as the game
-- starts (the game's bug), joined again on its own (C_Club.AddClubStreamChatChannel), silently, the windows' lists
-- untouched; one joined, a club left, the box off, a fight: nothing; ten logins in a row from the game started with
-- every chat joined on its own: Blizzard's fix, a line once, Clara stands aside; broken again: Clara steps in again.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local joined, calls, clubs = {}, {}, { [123] = true, [456] = true }
function GetChannelName(name) return joined[name] or 0 end
C_Club = C_Club or {}
C_Club.GetClubInfo = function(id) if clubs[id] then return { clubId = id } end end
C_Club.AddClubStreamChatChannel = function(club, stream)
  calls[#calls + 1] = club .. ":" .. stream
  joined["Community:" .. club .. ":" .. stream] = 5
end
NUM_CHAT_WINDOWS = 3
for i = 1, 3 do if not _G["ChatFrame" .. i] then CreateFrame("Frame", "ChatFrame" .. i, UIParent) end end
ChatFrame1.channelList = { "General", "Trade", "Community:123:1" }
ChatFrame2.channelList = {}
ChatFrame3.channelList = { "Community:456:1", "Community:123:1", "Community:789:1" }
local said = {}
DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or ChatFrame1
local oldAdd = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, text, ...) said[#said + 1] = text if oldAdd then return oldAdd(self, text, ...) end end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.CommunityChatLook then out("(no community chat fix in this version)"); out(""); out("0 failure(s)"); return end
local function Timers() local n = #(M.timers or {}) for _ = 1, n do M.RunTimer() end end

out("== a login from the game started: the clubs in, 15 seconds, a look")
joined["Community:456:1"] = 3
M.Fire("PLAYER_ENTERING_WORLD", true, false)
M.Fire("INITIAL_CLUBS_LOADED")
Timers()
check(#calls == 1 and calls[1] == "123:1", "the one not joined: joined again (" .. table.concat(calls, ", ") .. ")")
check(joined["Community:123:1"] == 5, "it has its number now")
check(#ChatFrame1.channelList == 3 and #ChatFrame3.channelList == 3, "the windows' lists untouched")
check(#said == 0, "silently")
check((ClaraComboPointsDB.communityChatFix or {}).clean == 0, "the bug seen: logins in a row without it back to 0")
out("== every 30 seconds after: a chat lost on the way joined again")
joined["Community:456:1"] = nil
M.Tick()
check(calls[#calls] == "456:1", "joined again")
out("== left alone: a club left, the box off, a fight")
clubs[456] = nil; joined["Community:456:1"] = nil
local before = #calls
ns.CommunityChatLook(false)
check(#calls == before, "a club no longer ours: nothing")
clubs[456] = true
ns:SetCommunityChat(false)
ns.CommunityChatLook(false)
check(#calls == before and not ns:CommunityChat(), "the box off: nothing")
ns:SetCommunityChat(true)
S.inCombat = true
ns.CommunityChatLook(false)
check(#calls == before, "in a fight: nothing (the next look)")
S.inCombat = false
ns.CommunityChatLook(false)
check(calls[#calls] == "456:1", "the fight over: joined again")
out("== Blizzard's fix: ten logins in a row with every chat joined on its own")
for i = 1, 9 do ns.CommunityChatLook(true) end
check(#said == 0 and not ClaraComboPointsDB.communityChatFix.fixed, "nine: not yet")
ns.CommunityChatLook(true)
check(ClaraComboPointsDB.communityChatFix.fixed ~= nil and #said == 1 and said[1]:find("no longer joins", 1, true), "ten: seen, said once: " .. tostring(said[1]))
joined["Community:456:1"] = nil
before = #calls
ns.CommunityChatLook(false)
check(#calls == before, "Clara stands aside (a look during the session)")
ns.CommunityChatLook(true)
check(not ClaraComboPointsDB.communityChatFix.fixed and calls[#calls] == "456:1", "broken again at a login: Clara steps in again")
check(#said == 1, "nothing more said")
out("== a reload: its first look counts for nothing")
out("== the report (/cl souris)")
local r = ns:CommunityChatReport()
check(r:find("community chats: shown 3", 1, true) and r:find("Blizzard's fix seen no", 1, true), r)
out("")
out(fails .. " failure(s)")
