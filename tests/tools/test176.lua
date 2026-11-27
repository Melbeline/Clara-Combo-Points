-- Chat look (Modules/ChatLook): in a player's chat line, the small head of their race in their sex after the name
-- (its box off by default), the level before it, the time and level clickable (the whole line in the copy box); each part with its box; the
-- line changed in place after the game's AddMessage, only the newest one and only if it is that event's; a line kept
-- secret, another event's, or a monster's left as it is.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false } }
-- the game's helpers the module reads
local info = { ["Player-1-0001"] = { "Druid", "DRUID", "Night Elf", "NightElf", 3, "Lia", "Forever", 40 },
  ["Player-1-0002"] = { "Warrior", "WARRIOR", "Dwarf", "Dwarf", 2, "Brom", "Forever", nil } }
function GetPlayerInfoByGUID(guid) local t = info[guid] if t then return unpack(t, 1, 8) end end
function GetRaceAtlas(race, gender) return ("raceicon-%s-%s"):format(race, gender) end
C_Texture = C_Texture or {}
C_Texture.GetAtlasInfo = function(name) return name:find("^raceicon%-") and {} or nil end
ChatFrameUtil = ChatFrameUtil or {}
ChatFrameUtil.GetTimestampFormat = function() return "[%H:%M:%S] " end
TimeUtil = TimeUtil or {}
TimeUtil.BetterDate = function() return "[12:00:00] " end
local copied
local ns = {}
S.class = "DRUID"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.ChatLookBuild then out("(no chat look in this version)"); out(""); out("0 failure(s)"); return end
ns.ShowCopyBox = function(text) copied = text end

local LINE = "[19:46:37] |Hchannel:PARTY|h[Party]|h |Hplayer:Lia-Forever:12:PARTY|h[Lia Moon]|h: re"
local args = { "re", "Lia-Forever", "", "", "", "", 0, 0, "", 0, 12, "Player-1-0001" }
local frame = { GetFont = function() return "font", 14 end }

out("== by default: the level and the copy, no head")
local sw0 = ns.qolSwitches.chatlook
local d = ns.ChatLookBuild(LINE, args, frame)
check(not sw0[1].get() and sw0[2].get() and sw0[3].get(), "the head's box off, the others on")
check(not d:find("|A:", 1, true) and d:find("[40]", 1, true) and d:find("|Haddon:", 1, true), "no head; the level and the copy link: " .. d)
out("== the owner's accounts (ICKSTU, WANJ and the WoW1 linked to them): the head shown by default")
local money, sync = ns.Money, ns.Sync
ns.Money = { db = { me = "THIS", accounts = { OTHER = { n = "WANJ" } } } }
ns.Sync = { OwnAccount = function(id) return id == "OTHER" end }
check(ns.ChatLookOwners() and sw0[1].get() and ns.ChatLookBuild(LINE, args, frame):find("|A:raceicon", 1, true), "WANJ linked to this one (its WoW1): the head shown")
ns.Money.db.accounts = { THIS = { n = "ICKSTU" } }
check(ns.ChatLookOwners() and sw0[1].get(), "ICKSTU itself: shown")
ns.Money.db.accounts = { OTHER = { n = "WoW1" }, FRIEND = { n = "WANJ" } }
check(not ns.ChatLookOwners() and not sw0[1].get(), "another player's WoW1 (a WANJ seen, not one of this computer's): not shown")
ns.Money.db.accounts = { OTHER = { n = "Wanj" } }
sw0[1].set(false)
check(ClaraComboPointsDB.chatLook.heads == false and not sw0[1].get(), "on the owner's account, unticked: kept off")
ClaraComboPointsDB.chatLook.heads = nil
ns.Money, ns.Sync = money, sync
sw0[1].set(true)
check(ClaraComboPointsDB.chatLook.heads == true, "its box ticked: kept")
out("== a night elf woman's line: her head after her name, her level before, the time and level clickable")
local o = ns.ChatLookBuild(LINE, args, frame)
check(o:find("|A:raceicon-nightelf-female:14:14:0:-4|a", 1, true) ~= nil, "her head, in her sex: " .. o)
local level = o:find("[40]", 1, true)
local name = o:find("|Hplayer:", 1, true)
local head = o:find("|A:raceicon", 1, true)
check(level and name and head and level < name and name < head and o:find("[Lia Moon]|h |A:", 1, true), "the level before the name, the head after it")
check(o:find("^|Haddon:ClaraComboPoints:line:[%x]+%-%d+|h%[19:46:37%]|h |Hchannel:") ~= nil, "the time a link, its space outside")
local key = o:match("^|H(addon:ClaraComboPoints:line:[^|]+)|h")
check(key and o:find("|H" .. key .. "|h|cffb8b8b8[40]|r|h", 1, true), "the level the same link")
check(ns.ChatLookPlain(o) == "[19:46:37] [Party] [40] [Lia Moon]: re", "the line as copied: " .. ns.ChatLookPlain(o))

out("== a dwarf man's: his head, in his sex; no level known: none")
local o2 = ns.ChatLookBuild("[19:47:00] |Hplayer:Brom-Forever:13:SAY|h[Brom]|h says: hi", { "hi", "Brom-Forever", [12] = "Player-1-0002" }, frame)
check(o2:find("raceicon-dwarf-male", 1, true) and not o2:find("%[%d+%]"), "his head, no level: " .. o2)
out("== his level seen (his target): shown")
S.target = { guid = "Player-1-0002", level = 22, name = "Brom", player = true }
UnitGUID = function(u) return u == "target" and "Player-1-0002" or nil end
UnitLevel = function(u) return u == "target" and 22 or 0 end
local o3 = ns.ChatLookBuild("[19:47:00] |Hplayer:Brom-Forever:14:SAY|h[Brom]|h says: hi", { "hi", "Brom-Forever", [12] = "Player-1-0002" }, frame)
check(o3:find("[22]", 1, true) ~= nil, "his level from the unit around")

out("== each part's box")
local sw = ns.qolSwitches.chatlook
check(sw and #sw == 3 and sw[1].label == "CL_HEADS" and sw[2].label == "CL_LEVEL" and sw[3].label == "CL_COPY", "its three boxes on its card")
sw[1].set(false)
local o4 = ns.ChatLookBuild(LINE, args, frame)
check(not o4:find("|A:", 1, true) and o4:find("[40]", 1, true), "the head unticked: no head, the level still")
sw[2].set(false)
o4 = ns.ChatLookBuild(LINE, args, frame)
check(not o4:find("[40]", 1, true), "the level unticked: none")
sw[3].set(false)
o4 = ns.ChatLookBuild(LINE, args, frame)
check(not o4:find("|Haddon:", 1, true) and o4 == LINE, "the copy unticked: the line as the game made it")
check(ClaraComboPointsDB.chatLook.heads == false and ClaraComboPointsDB.chatLook.level == false, "kept with Clara's settings")
for i = 1, 3 do sw[i].set(true) end
check(ClaraComboPointsDB.chatLook.heads == true and ClaraComboPointsDB.chatLook.level == nil, "ticked again: the head kept on, the level at its default")

out("== after the game's AddMessage: the newest line changed in place, if it is that event's")
local entry
local win = { GetFont = frame.GetFont, dirty = 0 }
function win:MarkDisplayDirty() self.dirty = self.dirty + 1 end
win.historyBuffer = { GetEntryAtIndex = function(_, i) return i == 1 and entry or nil end }
entry = { message = LINE, extraData = { 1, 2, 3, "CHAT_MSG_PARTY", args } }
ns.ChatLookAfter(win, LINE, 1, 1, 1, 1, 2, 3, "CHAT_MSG_PARTY", args)
check(entry.message ~= LINE and entry.message:find("raceicon-nightelf-female", 1, true) and win.dirty == 1, "changed, the window redrawn")
entry = { message = LINE, extraData = { 1, 2, 3, "CHAT_MSG_PARTY", {} } }
ns.ChatLookAfter(win, LINE, 1, 1, 1, 1, 2, 3, "CHAT_MSG_PARTY", args)
check(entry.message == LINE, "another event's line (its arguments not these): left as it is")
entry = { message = LINE, extraData = { 1, 2, 3, "CHAT_MSG_MONSTER_SAY", args } }
ns.ChatLookAfter(win, LINE, 1, 1, 1, 1, 2, 3, "CHAT_MSG_MONSTER_SAY", args)
check(entry.message == LINE, "a monster's: left as it is")
local secret = M.Secret(LINE)
entry = { message = secret, extraData = { 1, 2, 3, "CHAT_MSG_PARTY", args } }
local ok = pcall(ns.ChatLookAfter, win, secret, 1, 1, 1, 1, 2, 3, "CHAT_MSG_PARTY", args)
check(ok and entry.message == secret, "a line kept secret: left as it is, no error")

out("== a click on the time: the whole line, selected to copy")
local shown = { ns.ChatLookBuild(LINE, args, frame) }
local k2 = shown[1]:match("^|H(addon:ClaraComboPoints:line:[^|]+)|h")
local cf = { GetNumMessages = function() return #shown end, GetMessageInfo = function(_, i) return shown[i] end }
ns.ChatLookClicked(nil, k2, "[19:46:37]", "RightButton", cf)
check(copied == "[19:46:37] [Party] [40] [Lia Moon]: re", "the right click: " .. tostring(copied))
copied = nil
ns.ChatLookClicked(nil, "addon:Other:x", "x", "LeftButton", cf)
check(copied == nil, "another addon's link: nothing")


out("== with Prat: what it shows by the name left to it, the time of its own clickable")
local pratMods = {}
local function PratMod(profile) return { db = { profile = profile }, IsEnabled = function() return true end } end
Prat = { Addon = { GetModule = function(_, name) return pratMods[name] end } }
pratMods.PlayerNames = PratMod({ on = true, level = true })
local PRAT = "|cff999999[20:55:24]|r |Hchannel:channel:8|h[8. L2P]|h |cffaaaaaa[|r|Hplayer:Lia-Forever:20:CHANNEL:8|h|cffffff0040|r:|cff0070ddLia Moon|r|h|cffaaaaaa]|r: ouf"
local p1 = ns.ChatLookBuild(PRAT, args, frame)
check(not p1:find("[40]", 1, true), "Prat's level shown: Clara's not added: " .. p1)
check(p1:find("|cffaaaaaa]|r |A:raceicon-nightelf-female", 1, true) ~= nil, "the head after Prat's closing bracket, not inside it")
check(p1:find("^|Haddon:ClaraComboPoints:line:[%x]+%-%d+|h|cff999999%[20:55:24%]|r|h |Hchannel:") ~= nil, "Prat's time (in its color): the link to copy")
check(ns.ChatLookPlain(p1) == "[20:55:24] [8. L2P] [40:Lia Moon]: ouf", "copied as shown: " .. ns.ChatLookPlain(p1))
out("== Prat's level off: Clara's, before Prat's brackets")
pratMods.PlayerNames = PratMod({ on = true, level = false })
local PRAT2 = "|cff999999[20:55:24]|r |cffaaaaaa[|r|Hplayer:Lia-Forever:21:SAY|h|cff0070ddLia Moon|r|h|cffaaaaaa]|r says: ouf"
local p2 = ns.ChatLookBuild(PRAT2, args, frame)
check(p2:find("[40]|r|h |cffaaaaaa[|r|Hplayer:", 1, true) ~= nil, "[40] before the bracket: " .. p2)
out("== a level another addon put in the name: not twice, Prat or not")
Prat = nil
local p3 = ns.ChatLookBuild("[19:46:37] |Hplayer:Lia-Forever:22:SAY|h[40:Lia Moon]|h says: x", args, frame)
check(not p3:find("[40]", 1, true), "no second level: " .. p3)
local p4 = ns.ChatLookBuild("[19:46:37] |Hplayer:Lia-Forever:23:SAY|h[Lia Moon]|h |A:raceicon128-nightelf-female:14:14|a says: x", args, frame)
check(select(2, p4:gsub("raceicon", "")) == 1, "a race's head already there: not twice")
out("== Prat's time put after Clara's hook: Clara's change made next, Prat's time kept")
Prat = { Addon = { GetModule = function(_, name) return pratMods[name] end } }
pratMods.Timestamps = PratMod({ on = true })
pratMods.PlayerNames = PratMod({ on = true, level = true })
local RAWP = "|Hchannel:channel:8|h[8. L2P]|h |cffaaaaaa[|r|Hplayer:Lia-Forever:24:CHANNEL:8|h|cffffff0040|r:Lia Moon|h|cffaaaaaa]|r: ouf"
entry = { message = RAWP, extraData = { 1, 2, 3, "CHAT_MSG_CHANNEL", args } }
ns.ChatLookAfter(win, RAWP, 1, 1, 1, 1, 2, 3, "CHAT_MSG_CHANNEL", args)
check(entry.message == RAWP, "not changed yet: Prat's hook sees the line as made")
entry.message = "|cff999999[20:55:30]|r " .. entry.message -- (Prat's Timestamps)
ns.ChatLookFlush()
check(entry.message:find("^|Haddon:ClaraComboPoints:line:[^|]+|h|cff999999%[20:55:30%]|r|h") and entry.message:find("|A:raceicon", 1, true)
  and not entry.message:find("[40]", 1, true), "then changed: Prat's time clickable, the head, no second level: " .. entry.message)
pratMods.Timestamps = PratMod({ on = false })
entry = { message = LINE, extraData = { 1, 2, 3, "CHAT_MSG_PARTY", args } }
ns.ChatLookAfter(win, LINE, 1, 1, 1, 1, 2, 3, "CHAT_MSG_PARTY", args)
check(entry.message ~= LINE, "Prat's Timestamps off: changed at once")
Prat = nil

out("")
out(fails .. " failure(s)")
