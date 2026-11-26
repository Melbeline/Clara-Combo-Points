-- Who is online in a community (CommunityChat.lua): the Guild & Communities window's community subscribed to its
-- members' presence as it is picked (the window shown), as the game's chat channels window does; not the guild's;
-- shown again on the same community: subscribed again; the report says it.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local subscribed = {}
C_Club = { AddClubStreamChatChannel = function() end,
  SetClubPresenceSubscription = function(id) subscribed[#subscribed + 1] = id end,
  GetClubInfo = function(id) if id == "77" then return { name = "Les Lunes", clubType = 1 } end return { name = "Guilde", clubType = 2 } end }
Enum = Enum or {}
Enum.ClubType = { BattleNet = 0, Character = 1, Guild = 2, Other = 3 }
CommunitiesFrame = CreateFrame("Frame", "CommunitiesFrame", UIParent)
function CommunitiesFrame:OnClubSelected(clubId) self.selectedClubId = clubId end
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("ADDON_LOADED", "Blizzard_Communities")
if not ns.CommunityPresenceSubscribe then out("(no community presence in this version)"); out(""); out("0 failure(s)"); return end
CommunitiesFrame:Show()
CommunitiesFrame:OnClubSelected("77")
check(subscribed[#subscribed] == "77", "a community picked, the window shown: its members' presence asked for")
local n = #subscribed
CommunitiesFrame:OnClubSelected("12")
check(#subscribed == n, "the guild: left to its own roster")
CommunitiesFrame:OnClubSelected("77")
CommunitiesFrame:Hide()
n = #subscribed
CommunitiesFrame:OnClubSelected("77")
check(#subscribed == n, "the window hidden: nothing asked")
M.timers = {}
CommunitiesFrame:Show()
for _ = 1, 3 do if M.timers and #M.timers > 0 then M.RunTimer() end end
check(subscribed[#subscribed] == "77" and #subscribed == n + 1, "shown again on it: asked again")
check(ns:CommunityChatReport():find("presence asked for", 1, true) and ns:CommunityChatReport():find("Les Lunes", 1, true), ns:CommunityChatReport())
out("")
out(fails .. " failure(s)")
