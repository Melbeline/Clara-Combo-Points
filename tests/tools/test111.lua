-- Clara's characters (AltFriends.lua): an offline character never shown online. This WoW account's other characters
-- (one character at a time per account: the ones that logged in here, and the gold tracker's of this account) never
-- asked, never online, never announced; a server slow to answer (11 s late) never makes one online, each late answer
-- hidden, its pace learned; the friends list opened just after an unanswered question (two questions out): both
-- answers hidden, never online; a whisper of the player's own still shows; a stale question not taken for one
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
ChatFrameUtil.AddMessageEventFilter = function(event, fn) filters[event] = fn end
FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame:Hide()
function UnitNameUnmodified(u) if u == "player" then return "Lola", "Moon" end end
Constants = Constants or {}
Constants.CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " ", CHARACTERNAME_REALMNAME_SEPARATOR = "-" }
-- this account: Charlotte Moon logged in here before; Lia Moon is the gold tracker's (this account's), Bob Twink another's
ClaraComboPointsDB = { accountChars = { ["charlotte moon"] = 1 }, qol = { lfgforever = false, whatstraining = false, doesitdie = false,
  enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false,
  xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false,
  idtip = false, soloraidframe = false, enemycasts = false, reverseengineering = false } }
ClaraMoneyDB = { me = "acc1acc1", chars = {
  ["Lia-Realm"] = { n = "Lia", s = "Moon", r = "Realm", a = "acc1acc1", l = 20, m = 0 },
  ["Bob-Realm"] = { n = "Bob", s = "Twink", r = "Realm", a = "acc2acc2", l = 30, m = 0 } } }

M.now = 1000
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local A = ns.AltFriends
out("(money module: " .. tostring(ns.Money ~= nil) .. ")")
A.Add("Charlotte Moon"); A.Add("Lia Moon"); A.Add("Bob Twink"); A.Add("Piou Piou")
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
local answered = { ["Bob Twink"] = 0, ["Piou Piou"] = 0 }
for _ = 1, 40 do
  M.now = M.now + 1 M.Tick()
  for name, n in pairs(answered) do -- (Bob and Piou offline: the server answers at once)
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

out("== a server 11 s slow to answer: never online, each answer hidden")
A.Remove("Piou Piou")
local pending, shown, everOnline = {}, 0, false
local seen = AskedOf("Bob Twink")
M.chat = {}
for _ = 1, 150 do
  M.now = M.now + 1
  M.Tick()
  local n = AskedOf("Bob Twink")
  for _ = seen + 1, n do pending[#pending + 1] = M.now + 11 end
  seen = n
  while pending[1] and pending[1] <= M.now do
    table.remove(pending, 1)
    if not Answer("Bob Twink") then shown = shown + 1 end
  end
  if A.Online("Bob Twink") then everOnline = true end
end
check(not everOnline, "Bob never online")
check(not Chat("has come online"), "never announced")
check(shown == 0, "every late answer hidden")
check(A.Wait() > 2, "the server's pace learned: questions wait longer (" .. string.format("%.1f", A.Wait()) .. " s)")

out("== the friends list opened just after an unanswered question: both answers hidden, never online")
for _ = 1, 400 do M.now = M.now + 1 M.Tick() end -- (the pace forgotten, a fresh start)
A.Remove("Bob Twink"); A.Add("Zed Zorro")
M.chat = {}
local before = AskedOf("Zed Zorro")
local t0
for _ = 1, 15 do
  M.now = M.now + 1 M.Tick()
  if AskedOf("Zed Zorro") > before then t0 = M.now break end
end
M.now = t0 + 2; M.Tick() -- (unanswered 2 s)
M.now = t0 + 2.5
FriendsFrame:Show()
check(AskedOf("Zed Zorro") == before + 2, "asked again as the list opens")
M.now = t0 + 3
check(Answer("Zed Zorro"), "the first answer (3 s late): hidden")
M.now = t0 + 3.2
check(Answer("Zed Zorro"), "the second: hidden too")
FriendsFrame:Hide()
local on = false
for _ = 1, 30 do M.now = M.now + 1 M.Tick() if A.Online("Zed Zorro") then on = true end
  -- (each later question answered at once)
  local n = AskedOf("Zed Zorro")
  if n > before + 2 then before = n - 2 Answer("Zed Zorro") end
end
check(not on and not Chat("has come online"), "Zed never online")

out("== a whisper of the player's own: shown; a stale question not taken for one")
M.now = M.now + 5
local text = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Nobody Here")
check(filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, 999) == false, "no question to that name: the line stays")
A.Add("Kiki Kaka")
local asked
for _ = 1, 15 do M.now = M.now + 1 M.Tick() if AskedOf("Kiki Kaka") > 0 then asked = true break end end
M.Fire("CHAT_MSG_SAY", "coucou", "Kiki Kaka-Realm") -- (heard: online, its question answered)
check(asked and A.Online("Kiki Kaka"), "Kiki heard in the chat: online")
check(filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Kiki Kaka"), "", "", "", "", "", 0, 0, "", 0, 1000) == false,
  "its later logout, the player's whisper: the line stays (the question was answered)")
out(string.format("\n%d failure(s)", fails))
return fails
