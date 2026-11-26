-- Melbeline's addons' CommunityFix.lua (the same file in each): one copy runs (Clara's when Clara is there, else the
-- first to start); its community chats joined again when the game has not; the communities window's community
-- subscribed to its members' presence (not the guild's), the window shown.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local FIX = os.getenv("CFX_DIR") -- (a folder with CommunityFix.lua and a CFX.toc listing it)
local probe = FIX and io.open(FIX .. "/CFX.toc", "rb")
if not probe then out("(no CommunityFix.lua given: set CFX_DIR)"); out(""); out("0 failure(s)"); return end
probe:close()
local joined, subscribed = {}, {}
local channels = { ["Community:77:1"] = 0 }
C_Club = { GetClubInfo = function(id) if tostring(id) == "77" then return { name = "Les Lunes", clubType = 1 } end return { name = "G", clubType = 2 } end,
  AddClubStreamChatChannel = function(c, s) joined[#joined + 1] = c .. ":" .. s; channels["Community:" .. c .. ":" .. s] = 5 end,
  SetClubPresenceSubscription = function(id) subscribed[#subscribed + 1] = id end }
Enum = Enum or {}; Enum.ClubType = { BattleNet = 0, Character = 1, Guild = 2, Other = 3 }
GetChannelName = function(name) return channels[name] or 0 end
ChatFrame1.channelList = { "General", "Community:77:1" }
CommunitiesFrame = CreateFrame("Frame", "CommunitiesFrame", UIParent)
function CommunitiesFrame:OnClubSelected(clubId) self.selectedClubId = clubId end
local ns1, ns2 = {}, {}
M.LoadAddonAs(FIX, "CFX.toc", "ClassicFriendsList", ns1)
M.LoadAddonAs(FIX, "CFX.toc", "EasyFishing", ns2) -- (a second of these addons)
M.Fire("PLAYER_LOGIN")
check(ClaraCommunityFix == "ClassicFriendsList", "one copy runs: the first's (" .. tostring(ClaraCommunityFix) .. ")")
M.Fire("INITIAL_CLUBS_LOADED")
for _ = 1, 5 do if M.timers and #M.timers > 0 then M.RunTimer() end end
check(#joined == 1 and joined[1] == "77:1", "the community chat not joined: joined again, once: " .. table.concat(joined, ","))
CommunitiesFrame:Show()
CommunitiesFrame:OnClubSelected("77")
check(#subscribed == 1 and subscribed[1] == "77", "its members' presence asked for, once: " .. #subscribed)
CommunitiesFrame:OnClubSelected("12")
check(#subscribed == 1, "the guild: left alone")
out("== Clara there: these copies stand aside")
ClaraCommunityFix = "ClaraComboPoints"
local ns3 = {}
M.LoadAddonAs(FIX, "CFX.toc", "MinimapDrawer", ns3)
M.Fire("PLAYER_LOGIN")
check(ClaraCommunityFix == "ClaraComboPoints", "Clara's runs")
out("")
out(fails .. " failure(s)")
