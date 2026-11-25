-- Clara's characters (AltFriends.lua): one of the player's characters never asked, never online, while its WoW
-- account plays another (one character at a time per account): this account's (the ones that logged in here, the gold
-- tracker's of this account), and another account's while one of its characters is surely online (its Clara answered
-- or said hello, the sync heard it: never the server's silence), the newer word winning; the 2 s detection kept; a
-- server slow to answer: each late answer hidden and says offline, its pace learned; the friends list opened just
-- after an unanswered question (two questions out): both answers hidden; a whisper of the player's own still shows
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
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
function UnitNameUnmodified(u) if u == "player" then return "Lola", "Moon" end end
Constants = Constants or {}
Constants.CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " ", CHARACTERNAME_REALMNAME_SEPARATOR = "-" }
-- this account: Charlotte Moon logged in here before; Lia Moon is the gold tracker's (this account's); Bob Twink and Nina
-- Nox another account's
ClaraComboPointsDB = { accountChars = { ["charlotte moon"] = 1 }, qol = { lfgforever = false, whatstraining = false, doesitdie = false,
  enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false,
  xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false,
  idtip = false, soloraidframe = false, enemycasts = false, reverseengineering = false } }
ClaraMoneyDB = { me = "acc1acc1", chars = {
  ["Lia-Realm"] = { n = "Lia", s = "Moon", r = "Realm", a = "acc1acc1", l = 20, m = 0 },
  ["Bob-Realm"] = { n = "Bob", s = "Twink", r = "Realm", a = "acc2acc2", l = 30, m = 0 },
  ["Nina-Realm"] = { n = "Nina", s = "Nox", r = "Realm", a = "acc2acc2", l = 12, m = 0 } } }

M.now = 1000
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local A = ns.AltFriends
out("(money module: " .. tostring(ns.Money ~= nil) .. ")")
A.Add("Charlotte Moon"); A.Add("Lia Moon"); A.Add("Bob Twink"); A.Add("Nina Nox"); A.Add("Piou Piou")
M.addonSent = {}
M.Fire("PLAYER_LOGIN")
M.Tick()
M.Fire("PLAYER_ENTERING_WORLD", true, false)
local guard = 0 while M.timers and #M.timers > 0 and guard < 50 do M.RunTimer() guard = guard + 1 end
local function Ours() local t = {} for _, m in ipairs(M.addonSent) do if m[1] == "ClaraFriends" then t[#t + 1] = m end end return t end
local function AskedOf(name) local n = 0 for _, m in ipairs(Ours()) do if m[4] == name and m[2] == "?" then n = n + 1 end end return n end
local function Chat(pat) for _, line in ipairs(M.chat) do if line:find(pat, 1, true) then return true end end return false end
local line = 100
local function Answer(name) -- the server's answer, as the game hands it: each chat window's filter, then the event
  line = line + 1
  local text = ERR_CHAT_PLAYER_NOT_FOUND_S:format(name)
  local hidden = filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, line) == true
  local again = filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, line) == true
  M.Fire("CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, line)
  return hidden and again
end

out("== this WoW account's other characters: never asked, never online")
check(A.OnThisAccount("Charlotte Moon"), "Charlotte Moon: logged in here before")
check(A.OnThisAccount("Lia Moon"), "Lia Moon: the gold tracker's, of this account (first name and surname)")
check(not A.OnThisAccount("Bob Twink") and not A.OnThisAccount("Piou Piou"), "Bob (another account's), Piou: not")
check(ClaraComboPointsDB.accountChars["lola moon"] ~= nil, "this character kept as one of this account's")
M.chat = {}
local answered = { ["Bob Twink"] = 0, ["Nina Nox"] = 0, ["Piou Piou"] = 0 }
for _ = 1, 40 do
  M.now = M.now + 1 M.Tick()
  for name, n in pairs(answered) do -- (Bob, Nina and Piou offline: the server answers at once)
    for _ = n + 1, AskedOf(name) do Answer(name) end
    answered[name] = AskedOf(name)
  end
end
check(not A.Online("Bob Twink") and A.Known("Bob Twink"), "Bob: offline (answered at once)")
check(AskedOf("Charlotte Moon") == 0 and AskedOf("Lia Moon") == 0, "never asked")
check(AskedOf("Bob Twink") > 0 and AskedOf("Piou Piou") > 0, "the others asked")
check(not A.Online("Charlotte Moon") and A.Known("Charlotte Moon") and not A.Online("Lia Moon"), "offline, known")
M.Fire("CHAT_MSG_SAY", "coucou", "Charlotte Moon-Realm")
check(not A.Online("Charlotte Moon") and not Chat("[Charlotte Moon]"), "a name like hers heard: still offline, nothing said")

out("== another account of the player's playing one of its characters: its others never asked, never online")
local realm = ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""):gsub("%s", "")
ns.Sync = ns.Sync or { seen = {} }
ns.Sync.seen = ns.Sync.seen or {}
local function Keep(name, sec) -- sec seconds on: each question to it answered by its Clara, the others' left unanswered
  local seen = AskedOf(name)
  for _ = 1, sec do
    M.now = M.now + 1 M.Tick()
    local n = AskedOf(name)
    for _ = seen + 1, n do M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|30|MAGE|Duskwood", "WHISPER", name .. "-Realm") end
    seen = n
  end
end
M.chat = {}
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Bob Twink-Realm") -- (Bob logs in on the other account: his hello)
check(A.Online("Bob Twink"), "Bob: his Clara said hello, online")
check(A.AccountBusy("Nina Nox") and not A.Online("Nina Nox") and A.Known("Nina Nox"), "Nina, of Bob's account: offline")
local ninaAsked = AskedOf("Nina Nox")
Keep("Bob Twink", 40)
check(AskedOf("Nina Nox") == ninaAsked, "Nina never asked (the server says nothing of her)")
check(A.Online("Bob Twink") and not A.Online("Nina Nox") and not Chat("[Nina Nox]"), "40 s on: Bob online, Nina still offline, nothing said of her")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "!", "WHISPER", "Bob Twink-Realm") -- (Bob logs out: his goodbye)
local ninaSeen = ninaAsked
for _ = 1, 12 do -- (Nina offline: the server answers at once)
  M.now = M.now + 1 M.Tick()
  for _ = ninaSeen + 1, AskedOf("Nina Nox") do Answer("Nina Nox") end
  ninaSeen = AskedOf("Nina Nox")
end
check(not A.AccountBusy("Nina Nox") and AskedOf("Nina Nox") > ninaAsked, "Bob gone: Nina asked again")
check(not A.Online("Nina Nox"), "and offline (the server's answer)")

out("== the newer word counts: one heard by the sync, then another of its account logs in")
M.now = M.now + 1
ns.Sync.seen["Nina-" .. realm] = GetTime() -- (Nina on the other account, heard by the sync since)
check(A.Online("Nina Nox"), "Nina heard by the sync: online")
check(A.AccountBusy("Bob Twink") and not A.Online("Bob Twink"), "Bob, of her account: offline")
M.now = M.now + 5
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Bob Twink-Realm") -- (Nina gone without a word, Bob in)
check(A.Online("Bob Twink") and not A.AccountBusy("Bob Twink"), "Bob's hello, newer than the sync's word on Nina: Bob online")
check(not A.Online("Nina Nox"), "Nina: offline")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "!", "WHISPER", "Bob Twink-Realm")
ns.Sync.seen["Nina-" .. realm] = nil
A.Remove("Bob Twink"); A.Remove("Nina Nox"); A.Remove("Piou Piou")

out("== the server's silence: online after 2 s, as before")
A.Add("Max Vite")
local t1
for _ = 1, 15 do M.now = M.now + 1 M.Tick() if AskedOf("Max Vite") > 0 then t1 = M.now break end end
check(t1 ~= nil and not A.Online("Max Vite"), "Max asked")
check(A.Wait() == 2, "a server answering at once: 2 s")
M.now = t1 + 2; M.Tick()
check(A.Online("Max Vite"), "no answer in 2 s: online")
A.Remove("Max Vite")

out("== a server 11 s slow to answer: each late answer hidden and says offline, its pace learned")
A.Add("Zed Zorro")
local pending, shown, flips, lastOn = {}, 0, 0, false
local seen = AskedOf("Zed Zorro")
for _ = 1, 150 do
  M.now = M.now + 1
  M.Tick()
  local n = AskedOf("Zed Zorro")
  for _ = seen + 1, n do pending[#pending + 1] = M.now + 11 end
  seen = n
  while pending[1] and pending[1] <= M.now do
    table.remove(pending, 1)
    if not Answer("Zed Zorro") then shown = shown + 1 end
    if A.Online("Zed Zorro") then shown = shown + 100 end -- (an answer must say offline)
  end
  local on = A.Online("Zed Zorro") and true or false
  if on and not lastOn then flips = flips + 1 end
  lastOn = on
end
check(shown == 0, "every late answer hidden, each one saying offline")
check(A.Wait() > 2, "the server's pace learned: questions wait longer (" .. string.format("%.1f", A.Wait()) .. " s)")
check(flips <= 1, "online by mistake once at most, before the pace is learned (" .. flips .. ")")

out("== the friends list opened just after an unanswered question: both answers hidden")
for _ = 1, 400 do M.now = M.now + 1 M.Tick() end -- (the pace forgotten, a fresh start)
A.Remove("Zed Zorro"); A.Add("Uma Ulm")
local before = AskedOf("Uma Ulm")
local t0
for _ = 1, 15 do
  M.now = M.now + 1 M.Tick()
  if AskedOf("Uma Ulm") > before then t0 = M.now break end
end
M.now = t0 + 2; M.Tick() -- (unanswered 2 s)
M.now = t0 + 2.5
FriendsFrame:Show()
check(AskedOf("Uma Ulm") == before + 2, "asked again as the list opens")
M.now = t0 + 3
check(Answer("Uma Ulm"), "the first answer (3 s late): hidden")
check(not A.Online("Uma Ulm"), "and offline")
M.now = t0 + 3.2
check(Answer("Uma Ulm"), "the second: hidden too")
FriendsFrame:Hide()

out("== a whisper of the player's own: shown; a question answered in another way not taken for one")
M.now = M.now + 5
local text = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Nobody Here")
check(filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, 999) == false, "no question to that name: the line stays")
A.Add("Kiki Kaka")
local asked
for _ = 1, 15 do M.now = M.now + 1 M.Tick() if AskedOf("Kiki Kaka") > 0 then asked = true break end end
M.Fire("CHAT_MSG_SAY", "coucou", "Kiki Kaka-Realm") -- (heard: online, its question answered)
check(asked and A.Online("Kiki Kaka"), "Kiki heard in the chat: online")
check(filters.CHAT_MSG_SYSTEM(DEFAULT_CHAT_FRAME, "CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Kiki Kaka"), "", "", "", "", "", 0, 0, "", 0, 1000) == true,
  "the server's late word on the question asked just before it was heard: hidden")
check(A.Online("Kiki Kaka"), "and nothing said of it: still online")
M.now = M.now + 6
check(filters.CHAT_MSG_SYSTEM(DEFAULT_CHAT_FRAME, "CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Kiki Kaka"), "", "", "", "", "", 0, 0, "", 0, 1001) == true,
  "its later logout, the player's whisper: held back a moment (the question was answered)")
out(string.format("\n%d failure(s)", fails))
return fails
