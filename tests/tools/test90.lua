-- Characters in the friends list online or not (AltFriends.lua): an unseen addon whisper to each by its whole name,
-- one a second (each every 10 s, every 5 s with the list open, all at once at login and as the list opens); the
-- server's "No player named" = offline (that line hidden), 2 s of silence = online; heard in the chat = online; two
-- Clara with each other in their lists: hello and answer (level, class, zone) and goodbye at once, none at a reload;
-- comings and goings announced; Add Character's button opens its dialog
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
FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame:Hide()

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
local function Ours() local t = {} for _, m in ipairs(M.addonSent) do if m[1] == "ClaraFriends" then t[#t + 1] = m end end return t end
local function Sent() return #Ours() end
local function LastTo() local t = Ours() return t[#t] end
local function Chat(pat) for _, line in ipairs(M.chat) do if line:find(pat, 1, true) then return true end end return false end

out("== at login: everyone asked at once")
local asked = {}
for _, m in ipairs(Ours()) do asked[m[4]] = m[2] == "?" and m[3] == "WHISPER" end
check(Sent() == 2 and asked["Elle Woods"] and asked["Piou Piou"], "an unseen addon whisper to each, by the whole name")

out("== Elle offline: the server answers; Piou silent: online after 2 s")
local text = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Elle Woods")
check(filters.CHAT_MSG_SYSTEM and filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", text) == true, "the answer to our question hidden")
check(filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", text) == true, "in each chat window that shows it")
M.Fire("CHAT_MSG_SYSTEM", text)
check(not A.Online("Elle Woods") and A.Known("Elle Woods"), "Elle: offline, known")
M.now = 1001; M.Tick()
check(not A.Online("Piou Piou"), "Piou: not yet after 1 s")
M.now = 1002; M.Tick()
check(A.Online("Piou Piou"), "Piou: no answer in 2 s, online")
check(not Chat("has come online"), "the first answers after login: not announced")
check(Sent() == 2, "nobody asked again before 10 s")

out("== 10 s later: each asked again, one a second")
M.now = 1010; M.Tick()
check(Sent() == 3, "one asked")
M.now = 1011; M.Tick()
check(Sent() == 4, "the other a second later")
M.chat = {}
M.Fire("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Piou Piou"))
M.now = 1013; M.Tick()
check(A.Online("Elle Woods") and not A.Online("Piou Piou"), "Elle online, Piou offline")
check(Chat("[Elle Woods]|h has come online") and Chat("Piou Piou has gone offline"), "both announced, as the game says it")

out("== the friends list opened: everyone asked at once, then every 5 s")
M.addonSent = {}
M.now = 1015
FriendsFrame:Show()
check(Sent() == 2, "both asked as it opens")
M.now = 1020; M.Tick()
check(Sent() == 3, "asked again 5 s on while it stays open")
FriendsFrame:Hide()

out("== a whisper of the player's own to an offline friend: shown")
M.now = 1200
local mine = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Piou Piou")
check(filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", mine) == false, "not our question: the line stays")

out("== heard in the chat: online at once")
M.chat = {}
M.Fire("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Piou Piou"))
M.Fire("CHAT_MSG_CHANNEL", "salut", "Piou Piou-Realm")
check(A.Online("Piou Piou") and Chat("[Piou Piou]|h has come online"), "Piou online, announced")

out("== two Clara: a hello at its login, its answer, its goodbye, at once")
M.Fire("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Elle Woods"))
check(not A.Online("Elle Woods"), "Elle offline")
M.chat = {}
M.addonSent = {}
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Elle Woods-Realm")
check(A.Online("Elle Woods") and Chat("[Elle Woods]|h has come online"), "its hello: online and announced at once")
local reply = LastTo()
check(reply and reply[4] == "Elle Woods-Realm" and reply[2]:find("^I|%d+|PRIEST|") ~= nil, "answered with level, class, zone")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Elle Woods-Realm")
check(Sent() == 1, "not answered twice in 20 s")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Stranger-Realm")
check(Sent() == 1, "one not in the list: not answered")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|42|MAGE|Stranglethorn Vale", "WHISPER", "Elle Woods")
local facts = A.Facts("Elle Woods")
check(facts.level == 42 and facts.class == "MAGE" and facts.zone == "Stranglethorn Vale", "its level, class and zone shown")
check(type(facts.at) == "number", "last seen kept")
M.chat = {}
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "!", "WHISPER", "Elle Woods-Realm")
check(not A.Online("Elle Woods") and Chat("Elle Woods has gone offline"), "its goodbye: offline and announced at once")

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

out("== logout: a goodbye to the ones online; none at a reload")
M.addonSent = {}
M.Fire("PLAYER_LOGOUT")
local byes = {}
for _, m in ipairs(Ours()) do if m[2] == "!" then byes[m[4]] = true end end
check(byes["Lulu Bleue"] and byes["Piou Piou"] and not byes["Elle Woods"], "said to Lulu and Piou (online), not to Elle (offline)")
M.addonSent = {}
ReloadUI()
M.Fire("PLAYER_LOGOUT")
check(Sent() == 0, "a reload: no goodbye")

out("== Add Character: its button opens the dialog (the server's questions running)")
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
