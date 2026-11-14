-- Permanent Report Mute (Modules/ReportMute): a player reported with the game's Report button (a chat line's, a unit's)
-- is muted for good: saved for the account, their messages hidden in every chat (by GUID, by name without its realm);
-- not a group listing's or a club's report, nor a PvP AFK one; its page lists them with Remove, adds a name by hand;
-- a reported player known by name only learns their GUID; a secret author: no error, not hidden
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({ reportmute = true }, { __index = function() return false end }) }
function date(fmt, t) return "2026-11-14" end

-- the game's chat filters (the events, their filters), its report window, its chat lines
local filters = {}
ChatFrameUtil = { AddMessageEventFilter = function(event, fn) filters[event] = filters[event] or {}; table.insert(filters[event], fn) end }
local said = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) said[#said + 1] = text end }
Enum.ReportType = { Chat = 0, InWorld = 1, ClubFinderPosting = 2, ClubFinderApplicant = 3, GroupFinderPosting = 4,
  GroupFinderApplicant = 5, ClubMember = 6, GroupMember = 7, Friend = 8, Pet = 9, BattlePet = 10, Calendar = 11, Mail = 12,
  PvP = 13, PvPScoreboard = 14, PvPGroupMember = 15, CraftingOrder = 16, RecentAlly = 17 }
local LINES = { [501] = { "Player-1-00000ABC", "Grumpy Troll" } }
C_ChatInfo.GetChatLineSenderGUID = function(id) return LINES[id] and LINES[id][1] end
C_ChatInfo.GetChatLineSenderName = function(id) return LINES[id] and LINES[id][2] end
local function Location(kind, value)
  local loc = { kind = kind, value = value }
  function loc:GetGUID() return self.kind == "guid" and self.value or nil end
  function loc:IsUnit() return self.kind == "unit" end
  function loc:GetUnit() return self.value end
  function loc:IsChatLineID() return self.kind == "line" end
  function loc:GetChatLineID() return self.value end
  return loc
end
ReportFrame = CreateFrame("Frame", "ReportFrame", UIParent)
ReportFrame.ReportButton = CreateFrame("Button", nil, ReportFrame)
local sent = 0
ReportFrame.ReportButton:SetScript("OnClick", function(self) sent = sent + 1 end) -- (the game's own: SendReport)
local function Report(kind, name, loc, target)
  ReportFrame.reportInfo = { reportType = kind, reportTarget = target }
  ReportFrame.playerName = name
  ReportFrame.reportPlayerLocation = loc
  ReportFrame.ReportButton:Click()
end
local units = { target = "Player-1-00000DEF" }
local oldGUID = UnitGUID
function UnitGUID(u) return units[u] or oldGUID(u) end

S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Hidden(event, author, guid)
  for _, fn in ipairs(filters[event] or {}) do
    if fn(nil, event, "hello", author, "", "", "", "", 0, 0, "", 0, 7, guid) == true then return true end
  end
  return false
end

out("== reported from a chat line: muted for good")
check(ns:QolRuns("reportmute"), "on by default")
check(filters.CHAT_MSG_SAY and filters.CHAT_MSG_WHISPER and filters.CHAT_MSG_CHANNEL and filters.CHAT_MSG_GUILD, "its filter on every chat")
check(not Hidden("CHAT_MSG_SAY", "Grumpy Troll", "Player-1-00000ABC"), "before: shown")
Report(Enum.ReportType.Chat, "Grumpy Troll-Forever", Location("line", 501))
check(sent == 1, "the game's own report sent (its click untouched)")
local saved = ns.sv.reportMute and ns.sv.reportMute["Player-1-00000ABC"]
check(saved and saved.name == "Grumpy Troll-Forever" and saved.guid == "Player-1-00000ABC" and type(saved.when) == "number",
  "saved for the account, by its GUID, with its name")
check(said[#said]:find("Grumpy Troll%-Forever muted for good") ~= nil, "a line in the chat says so")
for _, event in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "CHAT_MSG_PARTY",
  "CHAT_MSG_RAID", "CHAT_MSG_GUILD", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_INSTANCE_CHAT" }) do
  if not Hidden(event, "Grumpy Troll", "Player-1-00000ABC") then check(false, event .. " hidden") end
end
check(true, "hidden in say, yell, whispers, channels, party, raid, guild, emotes, instance")
check(Hidden("CHAT_MSG_SAY", "Grumpy Troll-Forever", nil), "by name too (no GUID given)")
check(Hidden("CHAT_MSG_SAY", "grumpy troll", nil), "whatever the case, without the realm")
check(not Hidden("CHAT_MSG_SAY", "Kind Gnome", "Player-1-00000999"), "another player: shown")
local ok = pcall(Hidden, "CHAT_MSG_SAY", MOCK.Secret("Grumpy Troll"), MOCK.Secret("Player-1-00000ABC"))
check(ok, "a secret author: no error")
Report(Enum.ReportType.Chat, "Grumpy Troll-Forever", Location("line", 501))
local n = 0 for _ in pairs(ns.sv.reportMute) do n = n + 1 end
check(n == 1, "reported again: once")

out("== a unit's report; a group listing's, a club's, a PvP AFK one: not muted")
Report(Enum.ReportType.InWorld, "Rude Orc", Location("unit", "target"))
check(ns.sv.reportMute["Player-1-00000DEF"] and Hidden("CHAT_MSG_YELL", "Rude Orc", "Player-1-00000DEF"), "a unit's: by its GUID")
Report(Enum.ReportType.GroupFinderPosting, "Leader Name", nil)
Report(Enum.ReportType.ClubFinderPosting, "Some Club", nil)
Report(Enum.ReportType.PvP, "Afk Guy", Location("guid", "Player-1-00000777"))
check(not Hidden("CHAT_MSG_SAY", "Leader Name") and not Hidden("CHAT_MSG_SAY", "Some Club")
  and not Hidden("CHAT_MSG_SAY", "Afk Guy", "Player-1-00000777"), "a listing, a club, a PvP AFK report: nobody muted")

out("== its page: the list, Remove, a name added by hand")
local page = ns.ReportMutePage
page:GetScript("OnShow")(page)
check(page.count._text == "Muted for good: 2", "its count: " .. tostring(page.count._text))
page.box:SetText("Loud Human")
page.add:Click()
check(Hidden("CHAT_MSG_SAY", "Loud Human-Forever", nil) and ns.sv.reportMute["name:loud human"], "a name added by hand: hidden")
check(page.count._text == "Muted for good: 3", "listed")
Report(Enum.ReportType.Chat, "Loud Human", Location("guid", "Player-1-00000AAA"))
check(ns.sv.reportMute["Player-1-00000AAA"] and not ns.sv.reportMute["name:loud human"], "reported later: its GUID learned, once")
ns.ReportMuteRemove("Player-1-00000ABC")
check(not Hidden("CHAT_MSG_SAY", "Grumpy Troll", "Player-1-00000ABC") and ns.sv.reportMute["Player-1-00000ABC"] == nil,
  "Remove: shown again, out of the list")
check(said[#said]:find("no longer muted") ~= nil, "a line says so")
check(page.count._text == "Muted for good: 2", "the list follows")

out(string.format("\n%d failure(s)", fails))
return fails
