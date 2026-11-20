-- ClassicFriendsList: as Clara since its 15 November fixes. This WoW account's other characters (kept as each logs in)
-- never asked, never online (one character at a time per account); a late "No player named" still ours: hidden (in
-- each chat window that shows that line) and offline, after 2 s of silence took it for online; the server's slowness
-- learned (a longer wait after a slow answer)
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
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function() return false end
M.LoadAddonAs(ADDON_DIR, "ClassicFriendsList.toc", "ClassicFriendsList", ns)
M.Fire("ADDON_LOADED", "ClassicFriendsList")
local A = ns.CFL
ClassicFriendsListDB.chars = ClassicFriendsListDB.chars or {}
ClassicFriendsListDB.chars["lia moon"] = { level = 30, class = "PRIEST", at = 1 } -- (another character of this account)
A.Add("Elle Woods"); A.Add("Piou Piou"); A.Add("Lia Moon")
M.addonSent = {}
M.Fire("PLAYER_LOGIN")
M.Tick()
M.Fire("PLAYER_ENTERING_WORLD", true, false)
local guard = 0 while M.timers and #M.timers > 0 and guard < 50 do M.RunTimer() guard = guard + 1 end
local function AskedOf(name) for _, m in ipairs(M.addonSent) do if m[1] == "ClaraFriends" and m[4] == name then return true end end return false end

out("== this account's other character: never asked, never online")
check(AskedOf("Elle Woods") and AskedOf("Piou Piou"), "the others asked")
check(not AskedOf("Lia Moon"), "Lia Moon (this account) not asked")
check(A.Known("Lia Moon") and not A.Online("Lia Moon"), "known, offline")

out("== a late answer: hidden and offline, even after 2 s of silence took it for online")
M.now = M.now + 2.5; M.Tick()
check(A.Online("Elle Woods"), "Elle: 2 s of silence, online")
local text = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Elle Woods")
local function Filter(line) return filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, line) end
check(Filter(77) == true, "the late answer hidden")
check(Filter(77) == true, "the same line in another chat window: hidden there too")
M.Fire("CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, 77)
check(not A.Online("Elle Woods"), "Elle: offline after all")
check(Filter(78) == true, "another such line, no question left waiting: held back a moment (shown 3 s on unless heard from)")

out("== the server's slowness learned: a longer wait after a slow answer")
check(A.Wait() > 2, ("Elle's answer came 2.5 s late: the next questions wait %.1f s"):format(A.Wait()))
out(string.format("\n%d failure(s)", fails))
return fails
