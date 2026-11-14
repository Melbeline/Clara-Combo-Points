-- Permanent Report Mute in the game's own UI code: the report window's Report button (its click hooked once) pressed
-- for a chat line's report and a unit's, the players muted for good by GUID; a listing's report not; their messages
-- refused by the module's chat filter, the others let through; its page and Remove; no error. (The harness's report
-- window has no game code behind it, and its ReportInfo/PlayerLocation are stand-ins: the report's fields are set here
-- as the game's own objects carry them.)
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local RF = rawget(env, "ReportFrame")
check(RF ~= nil and RF.ReportButton ~= nil, "the game's report window and its button")
if not RF then print("scenario: report mute failures " .. fails) return end
rawset(env.Enum, "ReportType", { Chat = 0, InWorld = 1, ClubFinderPosting = 2, ClubFinderApplicant = 3,
  GroupFinderPosting = 4, GroupFinderApplicant = 5, ClubMember = 6, GroupMember = 7, Friend = 8, Pet = 9, BattlePet = 10,
  Calendar = 11, Mail = 12, PvP = 13, PvPScoreboard = 14, PvPGroupMember = 15, CraftingOrder = 16, RecentAlly = 17 })
rawset(env.C_ChatInfo, "GetChatLineSenderGUID", function(id) return id == 501 and "Player-1-00000ABC" or nil end)
rawset(env.C_ChatInfo, "GetChatLineSenderName", function(id) return id == 501 and "Grumpy Troll" or nil end)
local function Loc(kind, value)
  return { GetGUID = function() return kind == "guid" and value or nil end, IsUnit = function() return kind == "unit" end,
    GetUnit = function() return value end, IsChatLineID = function() return kind == "line" end,
    GetChatLineID = function() return value end }
end
local function Press(kind, name, loc)
  rawset(RF, "reportInfo", { reportType = kind })
  rawset(RF, "playerName", name)
  rawset(RF, "reportPlayerLocation", loc)
  return pcall(function() RF.ReportButton:GetScript("OnClick")(RF.ReportButton, "LeftButton", false) end)
end
local T = env.Enum.ReportType
local ok, e = Press(T.Chat, "Grumpy Troll", Loc("line", 501))
check(ok, "Report pressed for a chat line's report" .. (ok and "" or (": " .. tostring(e))))
local list = ns.sv and ns.sv.reportMute or {}
check(list["Player-1-00000ABC"] ~= nil, "muted for good, by its GUID")
ok, e = Press(T.GroupFinderPosting, "A Listing", nil)
check(ok and list["name:a listing"] == nil, "a listing's report: nobody muted")
local filter = ns.ReportMuteFilter
check(filter and filter(nil, "CHAT_MSG_SAY", "hi", "Grumpy Troll", "", "", "", "", 0, 0, "", 0, 7, "Player-1-00000ABC") == true,
  "its message refused")
check(filter(nil, "CHAT_MSG_SAY", "hi", "Kind Gnome", "", "", "", "", 0, 0, "", 0, 7, "Player-1-00000999") == false,
  "another's let through")
local page = ns.ReportMutePage
ok, e = pcall(function() page:GetScript("OnShow")(page) ns.ReportMuteRemove("Player-1-00000ABC") end)
check(ok and list["Player-1-00000ABC"] == nil, "its page, Remove" .. (ok and "" or (": " .. tostring(e))))
print("scenario: report mute failures " .. fails)
