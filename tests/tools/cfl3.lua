-- ClassicFriendsList (standalone) with Clara loaded: it stays off (Clara keeps the same list, draws the same rows and
-- the same Add Friend window, answers the same messages): said once in the chat, nothing hooked, nothing asked
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function Chat(pat) local n = 0 for _, line in ipairs(M.chat) do if line:find(pat, 1, true) then n = n + 1 end end return n end

FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame:Hide()
local prefixes = {}
C_ChatInfo.RegisterAddonMessagePrefix = function(p) prefixes[p] = true return true end
local hooks = 0
function FriendsList_Update() end
local realHook = hooksecurefunc
hooksecurefunc = function(...) hooks = hooks + 1 return realHook(...) end
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function(name) return name == "ClaraComboPoints" end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.chat = {}
M.LoadAddonAs(ADDON_DIR, "ClassicFriendsList.toc", "ClassicFriendsList", ns)
M.Fire("ADDON_LOADED", "ClassicFriendsList")
ClassicFriendsListDB.friends = { ["elle woods"] = { name = "Elle Woods" } }
M.addonSent = {}
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
for _ = 1, 30 do M.now = (M.now or 0) + 1; M.Tick() end
local guard = 0 while M.timers and #M.timers > 0 and guard < 50 do M.RunTimer() guard = guard + 1 end
hooksecurefunc = realHook

check(Chat("Clara is loaded and keeps this same list") == 1, "said once: Clara runs, ClassicFriendsList stays off")
check(not prefixes.ClaraFriends, "the addon messages left to Clara")
check(#M.addonSent == 0, "nobody asked")
check(hooks == 0 and ns.CFL.addPage == nil, "nothing hooked, no Add Friend page")
check(ns.CFL.AddToList() == 0, "no rows")
SlashCmdList.CLASSICFRIENDSLIST("add Rose Thorn")
check(Chat("Clara is loaded") == 2 and ClassicFriendsListDB.friends["rose thorn"] == nil, "/cfl: says Clara runs, adds nothing")
check(ClassicFriendsListDB.friends["elle woods"] ~= nil, "its list kept for when Clara is gone")
out(string.format("\n%d failure(s)", fails))
return fails
