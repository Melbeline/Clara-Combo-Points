-- "No player named" then "has come online" (AltFriends.lua): the server's not-found line that answers no question of
-- ours, naming a character of the list, held back 3 s; the character heard from meanwhile: neither line shown; else the
-- line shown then, and offline. Our answers' own not-found hidden, saying nothing of it; a question asked just before
-- the character was heard from: its late not-found hidden, saying nothing of it; a question asked since: offline as
-- ever; a name not in the list: shown at once
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
GetNetStats = function() return 0, 0, 50, 50 end

M.now = 1000
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local A = ns.AltFriends
A.Add("Xxjeanne Darkxx"); A.Add("Elle Woods")
M.addonSent = {}
M.Fire("PLAYER_LOGIN")
M.Tick()
M.Fire("PLAYER_ENTERING_WORLD", true, false)
local function Timers() local n = 0 while M.timers and #M.timers > 0 and n < 50 do M.RunTimer() n = n + 1 end end
Timers()
local function Chat(pat) for _, line in ipairs(M.chat) do if line:find(pat, 1, true) then return true end end return false end
local function Asked(name) local n = 0 for _, m in ipairs(M.addonSent) do if m[1] == "ClaraFriends" and m[2] == "?" and m[4] == name then n = n + 1 end end return n end
-- A system line as the game gives it: each chat window's filter first (hidden when one says so), then the events
local line = 5000
local function System(text)
  line = line + 1
  local hidden = filters.CHAT_MSG_SYSTEM(DEFAULT_CHAT_FRAME, "CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, line)
  if not hidden then DEFAULT_CHAT_FRAME:AddMessage(text) end
  M.Fire("CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, line)
  return hidden
end
local NF = function(name) return ERR_CHAT_PLAYER_NOT_FOUND_S:format(name) end
local function Tick(seconds) for _ = 1, seconds do M.now = M.now + 1; M.Tick() end end

-- (both offline: the first answers, then the first 20 s over)
for _, name in ipairs({ "Xxjeanne Darkxx", "Elle Woods" }) do System(NF(name)) end
Tick(25)
for _ = 1, 3 do for _, name in ipairs({ "Xxjeanne Darkxx", "Elle Woods" }) do System(NF(name)) end Tick(1) end
check(not A.Online("Xxjeanne Darkxx") and not A.Online("Elle Woods"), "both offline")

out("== a not-found that answers no question of ours, then it is heard from within 3 s: neither line")
M.chat = {}
local nf = NF("Xxjeanne Darkxx")
check(System(nf) == true and not Chat(nf), "the line held back")
M.now = M.now + 1.5
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Xxjeanne Darkxx")
check(A.Online("Xxjeanne Darkxx"), "heard from: online")
check(not Chat("has come online"), "its has come online not said")
Timers()
check(not Chat(nf) and A.Online("Xxjeanne Darkxx"), "3 s on: the line dropped, still online")

out("== our answer to it, the server saying not found: hidden, nothing said of it")
M.now = M.now + 0.3
check(System(nf) == true, "the not-found for our answer hidden")
Timers()
check(not Chat(nf) and A.Online("Xxjeanne Darkxx") and not Chat("has gone offline"), "still online, nothing in the chat")

out("== a question asked, the character heard from, the late not-found for that question: hidden, still online")
M.now = M.now + 20
local before = Asked("Xxjeanne Darkxx")
local guard = 0 while Asked("Xxjeanne Darkxx") == before and guard < 20 do Tick(1) guard = guard + 1 end
check(Asked("Xxjeanne Darkxx") > before, "asked")
M.now = M.now + 0.3
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|30|PRIEST|Elwynn Forest", "WHISPER", "Xxjeanne Darkxx")
M.now = M.now + 0.3
check(System(nf) == true, "the late not-found hidden")
Timers()
check(A.Online("Xxjeanne Darkxx") and not Chat(nf) and not Chat("has gone offline"), "still online, nothing in the chat")

out("== our answer long ago, a question since unanswered by her Clara: its not-found is that question's: offline")
M.now = M.now + 15
before = Asked("Xxjeanne Darkxx")
guard = 0 while Asked("Xxjeanne Darkxx") == before and guard < 20 do Tick(1) guard = guard + 1 end
M.now = M.now + 0.2
check(System(nf) == true and not Chat(nf), "hidden (our question's answer)")
check(not A.Online("Xxjeanne Darkxx") and Chat("Xxjeanne Darkxx has gone offline"), "offline at once, said as the game says it")

out("== a not-found that answers nothing of ours, nobody heard from: shown 3 s on, offline")
M.chat = {}
local elle = NF("Elle Woods")
check(System(elle) == true and not Chat(elle), "held back")
Timers()
check(Chat(elle) and not A.Online("Elle Woods"), "3 s on: shown, offline")

out("== a name not in the list: shown at once")
M.chat = {}
local other = NF("Nobody Here")
check(System(other) == false and Chat(other), "shown at once")

out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
