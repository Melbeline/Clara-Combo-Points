-- Characters in the friends list online or not (AltFriends.lua): an unseen addon whisper to each, one at a time;
-- the server's "No player named" = offline (that line hidden), silence = online; heard in the chat = online; a
-- friend's Clara with this character in its list answers with level, class, zone; comings and goings announced
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h has come online."
ERR_FRIEND_OFFLINE_S = "%s has gone offline."
local filters = {}
ChatFrameUtil = ChatFrameUtil or {}
ChatFrameUtil.AddMessageEventFilter = function(event, fn) filters[event] = fn end

M.now = 1000
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local A = ns.AltFriends
A.Add("Elle Woods"); A.Add("Piou Piou")
M.addonSent = {}
M.Fire("PLAYER_LOGIN")
local guard = 0 while M.timers and #M.timers > 0 and guard < 50 do M.RunTimer() guard = guard + 1 end -- (settled: the first 20 s over)
local function Sent() local n = 0 for _, m in ipairs(M.addonSent) do if m[1] == "ClaraFriends" then n = n + 1 end end return n end
local function LastTo() for i = #M.addonSent, 1, -1 do if M.addonSent[i][1] == "ClaraFriends" then return M.addonSent[i] end end end
local function Chat(pat) for _, line in ipairs(M.chat) do if line:find(pat, 1, true) then return true end end return false end

out("== the first questions, one a second")
M.Tick()
local first = LastTo()
check(Sent() == 1 and first[2] == "?" and first[3] == "WHISPER", "one unseen addon whisper")
check(first[4] == "Elle Woods" or first[4] == "Piou Piou", "to the whole name, first name and surname (" .. tostring(first[4]) .. ")")
M.now = 1001; M.Tick()
check(Sent() == 2, "the other one a second later (never asked yet)")
M.now = 1002; M.Tick()
check(Sent() == 2, "no third: each one asked")

out("== Elle offline: the server answers; Piou silent: online")
local text = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Elle Woods")
check(filters.CHAT_MSG_SYSTEM and filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", text) == true, "the answer to our question hidden")
check(filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", text) == true, "in each chat window that shows it")
M.Fire("CHAT_MSG_SYSTEM", text)
check(not A.Online("Elle Woods") and A.Known("Elle Woods"), "Elle: offline, known")
M.now = 1006; M.Tick()
check(A.Online("Piou Piou"), "Piou: no answer in 4 s, online")
check(not Chat("has come online"), "the first answers after login: not announced")

out("== later: Elle comes online, Piou goes")
M.now = 1100
M.chat = {}
M.Tick() -- (both due again: one asked now)
M.now = 1103; M.Tick()
check(Sent() == 4, "each asked again after 30 s, one every 3 s")
M.Fire("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Piou Piou"))
M.now = 1108; M.Tick()
check(A.Online("Elle Woods") and not A.Online("Piou Piou"), "Elle online, Piou offline")
check(Chat("[Elle Woods]|h has come online") and Chat("Piou Piou has gone offline"), "both announced, as the game says it")

out("== a whisper of the player's own to an offline friend: shown")
M.now = 1200
local mine = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Piou Piou")
check(filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", mine) == false, "not our question: the line stays")

out("== heard in the chat: online at once")
M.chat = {}
M.Fire("CHAT_MSG_CHANNEL", "salut", "Piou Piou-Realm")
check(A.Online("Piou Piou") and Chat("[Piou Piou]|h has come online"), "Piou online, announced")

out("== a friend's Clara: our question answered, its answer read")
M.addonSent = {}
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Elle Woods-Realm")
local reply = LastTo()
check(reply and reply[4] == "Elle Woods-Realm" and reply[2]:find("^I|%d+|PRIEST|") ~= nil, "answered with level, class, zone")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Elle Woods-Realm")
check(Sent() == 1, "not twice in 20 s")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Stranger-Realm")
check(Sent() == 1, "one not in the list: not answered")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|42|MAGE|Stranglethorn Vale", "WHISPER", "Elle Woods")
local facts = A.Facts("Elle Woods")
check(facts.level == 42 and facts.class == "MAGE" and facts.zone == "Stranglethorn Vale", "its level, class and zone shown")
check(type(facts.at) == "number", "last seen kept")
out("== the game says at once the target is offline (the send's own answer)")
local realSend = C_ChatInfo.SendAddonMessage
A.Add("Lulu Bleue")
C_ChatInfo.SendAddonMessage = function(prefix, text, chatType, target)
  table.insert(M.addonSent, { prefix, text, chatType, target })
  if target == "Lulu Bleue" then return 12 end
end
M.now = 1300
for _ = 1, 3 do M.Tick() M.now = M.now + 1 end
C_ChatInfo.SendAddonMessage = realSend
check(A.Known("Lulu Bleue") and not A.Online("Lulu Bleue"), "Lulu: offline at once (TargetOffline)")

out("== a first name heard alone: the one character of the list with it")
M.Fire("CHAT_MSG_SAY", "coucou", "Lulu")
check(A.Online("Lulu Bleue"), "Lulu heard by its first name: online")

out("== Add Character: its button opens the dialog (the server's questions running)")
FriendsFrame = FriendsFrame or CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrameAddFriendButton = FriendsFrameAddFriendButton or CreateFrame("Button", "FriendsFrameAddFriendButton", FriendsFrame)
FriendsFrameSendMessageButton = FriendsFrameSendMessageButton or CreateFrame("Button", "FriendsFrameSendMessageButton", FriendsFrame)
M.Tick()
M.popup = nil
check(A.LayFoot() and A.button ~= nil, "laid between Add Friend and Send Message")
local click = A.button and A.button:GetScript("OnClick")
if click then click(A.button) end
check(M.popup ~= nil and M.popup.which == "CLARA_ADD_ALT", "the dialog shown")
check(A.Ask ~= A.AskServer, "the dialog's opener not taken by the server's questions")
out(string.format("\n%d failure(s)", fails))
return fails
