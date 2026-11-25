-- Characters in the friends list online or not (AltFriends.lua): an unseen addon whisper to each by its whole name,
-- one a second (each every 10 s, every 5 s with the list open, all at once at login and as the list opens); the
-- server's "No player named" = offline (that line hidden), 2 s of silence = online; heard in the chat by the whole
-- name = online; two
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
local chains = {}
ChatFrameUtil.AddMessageEventFilter = function(event, fn) -- (as the game: every filter of the event, in order)
  chains[event] = chains[event] or {}
  table.insert(chains[event], fn)
  filters[event] = function(frame, ev, ...)
    local n, args = select("#", ...), { ... }
    for _, f in ipairs(chains[event]) do
      local r = { f(frame, ev, unpack(args, 1, n)) }
      if r[1] then return true end
      if r[2] ~= nil then n = math.max(n, #r - 1); args = { select(2, unpack(r, 1, n + 1)) } end
    end
    return false, unpack(args, 1, n)
  end
end
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
M.Tick()
local beforeWorld = #M.addonSent
M.Fire("PLAYER_ENTERING_WORLD", true, false) -- (the questions a moment after the world shows: answers came late in a loading screen)
local guard = 0 while M.timers and #M.timers > 0 and guard < 50 do M.RunTimer() guard = guard + 1 end -- (settled: the first 20 s over)
local function Ours() local t = {} for _, m in ipairs(M.addonSent) do if m[1] == "ClaraFriends" then t[#t + 1] = m end end return t end
local function Sent() return #Ours() end
local function LastTo() local t = Ours() return t[#t] end
-- (a coming or going said a moment later: the timers run first)
local function Chat(pat)
  if pat:find("has come online", 1, true) or pat:find("has gone offline", 1, true) then
    local guard = 0 while M.timers and #M.timers > 0 and guard < 50 do M.RunTimer() guard = guard + 1 end
  end
  for _, line in ipairs(M.chat) do if line:find(pat, 1, true) then return true end end
  return false
end

out("== at login: nothing asked before the world shows, then everyone at once")
check(beforeWorld == 0, "nothing asked during the loading")
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

out("== the friends list opened: everyone asked at once, then every 3 s")
M.addonSent = {}
M.now = 1015
FriendsFrame:Show()
check(Sent() == 2, "both asked as it opens")
M.now = 1018; M.Tick()
check(Sent() == 3, "asked again 3 s on while it stays open")
FriendsFrame:Hide()

out("== a whisper of the player's own to an offline friend: held back 3 s, then shown")
M.now = 1200
local mine = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Piou Piou")
M.chat = {}
check(filters.CHAT_MSG_SYSTEM(DEFAULT_CHAT_FRAME, "CHAT_MSG_SYSTEM", mine) == true and not Chat(mine), "not our question: held back a moment")
local held = 0 while M.timers and #M.timers > 0 and held < 10 do M.RunTimer() held = held + 1 end
check(Chat(mine), "not heard from meanwhile: the line shown then")

out("== heard in the chat: online at once")
M.chat = {}
M.Fire("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Piou Piou"))
M.Fire("CHAT_MSG_CHANNEL", "salut", "Piou Piou-Realm")
check(A.Online("Piou Piou") and Chat("[Piou Piou]|h has come online"), "Piou online, announced")

out("== two Clara: a hello at its login, its answer, its goodbye, at once")
M.Fire("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Elle Woods"))
local held = 0 while M.timers and #M.timers > 0 and held < 10 do M.RunTimer() held = held + 1 end -- (held back 3 s)
check(not A.Online("Elle Woods"), "Elle offline")
M.chat = {}
M.addonSent = {}
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Elle Woods-Realm")
check(A.Online("Elle Woods") and Chat("[Elle Woods]|h has come online"), "its hello: online and announced at once")
local reply = LastTo()
check(reply and reply[4] == "Elle Woods-Realm" and reply[2]:find("^I|%d+|PRIEST|") ~= nil, "answered with level, class, zone")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Elle Woods-Realm")
check(Sent() == 1, "not answered twice at once")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Stranger-Realm")
local toStranger = LastTo()
check(Sent() == 2 and toStranger and toStranger[4] == "Stranger-Realm" and toStranger[2]:find("^I|%d+|PRIEST|") ~= nil,
  "one not in the list asking: answered all the same (what /who tells anyone)")
check(not A.Online("Stranger"), "and not taken into the list")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Stranger-Realm")
check(Sent() == 2, "the stranger not answered twice at once")
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

out("== a first name heard alone: not taken (another player may have it)")
M.Fire("CHAT_MSG_SAY", "coucou", "Lulu")
check(not A.Online("Lulu Bleue"), "Lulu heard by its first name only: still offline")
M.Fire("CHAT_MSG_SAY", "coucou", "Lulu Bleue-Realm")
check(A.Online("Lulu Bleue"), "heard by its whole name: online")

out("== one of the player's other accounts: the sync's word and the server's, the newer counts")
ns.Sync = ns.Sync or { seen = {} }
ns.Sync.seen = ns.Sync.seen or {}
local realm = ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""):gsub("%s", "")
A.Add("Bob Twink")
M.now = 1400
ns.Sync.seen["Bob-" .. realm] = GetTime()
check(A.Online("Bob Twink"), "heard by the sync: online")
M.addonSent = {}
for _ = 1, 4 do M.now = M.now + 1 M.Tick() end
local askedBob = false
for _, m in ipairs(Ours()) do if m[4] == "Bob Twink" and m[2] == "?" then askedBob = true end end
check(askedBob, "asked of the server too (not left to the sync)")
M.now = 1406
M.Fire("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Bob Twink"))
check(not A.Online("Bob Twink"), "the server's newer answer: offline at once (the sync still counting it)")
M.now = 1410
ns.Sync.seen["Bob-" .. realm] = GetTime()
check(A.Online("Bob Twink"), "the sync heard it again since: online")

out("== logout: a goodbye to the ones online; none at a reload")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Elle Woods-Realm") -- (Elle, who has Clara, back online)
M.addonSent = {}
M.Fire("PLAYER_LOGOUT")
local byes = {}
for _, m in ipairs(Ours()) do if m[2] == "!" then byes[m[4]] = true end end
check(byes["Elle Woods"] and not byes["Lulu Bleue"] and not byes["Piou Piou"], "said to Elle (Clara, online) only: the others have no Clara to hear it")
M.addonSent = {}
ReloadUI()
M.Fire("PLAYER_LOGOUT")
check(Sent() == 0, "a reload: no goodbye")

out("== a late answer (after a loading screen) still hidden; a zone change: the unanswered asked again, not taken for online")
M.now = 1500
M.addonSent = {}
for _ = 1, 12 do M.Tick() M.now = M.now + 1 end
local lateName
for _, m in ipairs(Ours()) do if m[2] == "?" then lateName = m[4] end end
local lateText = ERR_CHAT_PLAYER_NOT_FOUND_S:format(lateName or "?")
M.now = M.now + 6
check(lateName ~= nil and filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", lateText) == true, "answered 6 s late: hidden")
M.addonSent = {}
for _ = 1, 3 do M.Tick() M.now = M.now + 1 end
local pend
for _, m in ipairs(Ours()) do if m[2] == "?" then pend = m[4] end end
local before = pend and A.Online(pend)
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.now = M.now + 2.5; M.Tick()
check(pend ~= nil and A.Online(pend) == before, "a question left in the loading: not taken for online")

out("== the next login: the ones with Clara greeted the moment the world shows; a hello answered at once")
M.addonSent = {}
M.Fire("PLAYER_ENTERING_WORLD", true, false)
local hello = {}
for _, m in ipairs(Ours()) do if m[2] == "?" then hello[m[4]] = true end end
check(hello["Elle Woods"] and not hello["Piou Piou"], "Elle (Clara) greeted at once; the others a moment later")
M.addonSent = {}
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Elle Woods-Realm")
M.now = M.now + 3
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Elle Woods-Realm")
local answers = 0
for _, m in ipairs(Ours()) do if m[2]:find("^I|") then answers = answers + 1 end end
check(answers == 2, "each hello answered (3 s apart): the one who reloaded sees this one at once")

out("== added and removed: said in the chat as the game says it, with the whole name")
M.chat = {}
check(A.Add("Melbeline moon"), "added")
check(Chat("Melbeline Moon added to friends."), "\"Melbeline moon\" typed: \"Melbeline Moon added to friends.\" (each word its capital)")
check(not A.Add("melbeline Moon") and Chat("Melbeline Moon is already your friend."), "twice: already a friend")
M.Fire("CHAT_MSG_SAY", "coucou", "Melbeline Moon-Realm")
check(A.List()["melbeline moon"].name == "Melbeline Moon", "the name as the game writes it, once heard whole")
M.chat = {}
check(A.Remove("Melbeline Moon") and Chat("Melbeline Moon removed from friends."), "removed, said")

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
