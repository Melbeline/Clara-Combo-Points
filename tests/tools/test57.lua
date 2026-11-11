-- UnitScan (UnitScan.lua, ScanPage.lua): what it looks for, the alert, the taskbar let through and put
-- back, other players' sightings in UnitScan Hardcore Forever's format (heard always, sent only when
-- asked), the hunted mob's key, its options page; the screenshots (Screenshots.lua)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false } }
local CVARS = { EnableBlinkApplicationIcon = "0", nameplateMaxDistance = "20" }
C_CVar = { GetCVar = function(n) return CVARS[n] end, SetCVar = function(n, v) CVARS[n] = tostring(v) end }
local filters = {}
ChatFrameUtil = { AddMessageEventFilter = function(event, fn) filters[event] = filters[event] or {}; table.insert(filters[event], fn) end }
local itemRefs = {}
EventRegistry = { RegisterCallback = function(_, event, fn, owner) itemRefs[#itemRefs + 1] = fn end }
local instance = { kind = "none" }
function GetInstanceInfo() return "Somewhere", instance.kind, 0, "", 5, 0, false, 0 end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
S.channels = { "General", "Trade" }
S.map = { id = 1417, x = .456, y = .789, name = "Arathi Highlands" }
S.units = {}
M.now = 1000
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
Run()
local function Logged(text) for _, l in ipairs(M.log) do if l:find(text, 1, true) then return l end end end

out("== its channel and prefix")
check(M.joined[1] == "ushccomms", "ushccomms joined, after the game's own channels")
check(M.prefixes and M.prefixes.USHC, "the USHC prefix registered (UnitScan Hardcore's addon messages)")
-- (the chat's filters: a line is hidden if one of them says so)
local function quiet(...)
  for _, fn in ipairs(filters.CHAT_MSG_CHANNEL or {}) do if fn(...) == true then return true end end
  return false
end
check(quiet(nil, "CHAT_MSG_CHANNEL", "USHC B64:x", "Bob-Forever", "", "5. ushccomms", "", "", 0, 5, "ushccomms") == true,
  "its lines never shown in a chat window")
check(quiet(nil, "CHAT_MSG_CHANNEL", "wts", "Bob", "", "2. Trade", "", "", 0, 2, "Trade") == false, "other channels' lines left alone")
table.insert(S.channels, "ushccomms")

out("== a rare in sight")
local secure = ClaraScanButton
S.units.nameplate3 = { name = "Prince Nazjak", guid = "Creature-0-4395-0-25-2779-0000ABC", level = 40, classification = "rare" }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
Run()
secure = ClaraScanButton
check(secure and secure:IsShown() and secure:GetAttribute("macrotext1") == "/targetexact Prince Nazjak\n/target [@nameplate3]",
  "the window: a click targets it, by its name and by its nameplate (" .. tostring(secure:GetAttribute("macrotext1")) .. ")")
check(secure.title:GetText() == "Prince Nazjak" and secure.sub:GetText() == "Rare in sight", "its name, and what it is")
check(M.flashed == 1, "the game's icon flashed in the taskbar")
check(CVARS.EnableBlinkApplicationIcon == "1", "the taskbar let through for it (Clara's box had it off)")
M.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
check(CVARS.EnableBlinkApplicationIcon == "0", "back in the game (a click): the taskbar off again")
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
check(M.flashed == 1, "the same creature again within a minute: no second alert")
check(#M.sent == 0 and #M.addonSent == 0, "nothing sent: sharing is off by default")
S.units.nameplate4 = { name = "Prince Nazjak", guid = "Creature-0-4395-0-25-2779-0000ABD", dead = true }
M.now = 1100
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
check(M.flashed == 1, "a dead one: no alert")
S.units.nameplate5 = { name = "Kobold Vermin", guid = "Creature-0-4395-0-25-6-0000ABE" }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
check(M.flashed == 1, "a creature not looked for: nothing")
M.now = 1200
S.units.nameplate3 = nil
M.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate3"); while M.timers and #M.timers > 0 do M.RunTimer() end
check(secure:GetAttribute("macrotext1") == "/targetexact Prince Nazjak", "its nameplate gone: by its name alone")
secure:GetScript("OnUpdate")(secure)
check(not secure:IsShown(), "the window gone after a while")

out("== names looked for")
SlashCmdList.CLARACOMBOPOINTS("scan Défias Pillager")
check(Logged("Défias Pillager added"), "/cl scan Name: added (a line in the chat)")
S.units.nameplate6 = { name = "Defias Pillager", guid = "Creature-0-4395-0-25-589-0000AB1" }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
check(M.flashed == 2 and secure:GetAttribute("macrotext1") == "/targetexact Defias Pillager\n/target [@nameplate6]", "any creature of that name, accents aside")
SlashCmdList.CLARACOMBOPOINTS("scan defias pillager")
check(#ns:ScanNames() == 0, "typed again: removed")
S.units.nameplate7 = { name = "Thrall", guid = "Player-1-0000001", player = true, enemy = true, attackable = true, level = 60 }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate7")
check(M.flashed == 2, "an enemy player: nothing by default")
ns:SetScanOption("players", true)
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate7")
check(M.flashed == 3 and secure.sub:GetText():find("Enemy player", 1, true), "enemy players ticked: the alert")
ns:SetScanOption("players", false)

out("== other players' sightings (UnitScan Hardcore Forever)")
local codec = ns.ScanCodec
check(codec.Decode(codec.Encode("PRINCE NAZJAK|1417|456|789|3")) == "PRINCE NAZJAK|1417|456|789|3", "its Base64, both ways")
check(codec.Encode("MOTHER FANG|1429|420|650|2") == "TU9USEVSIEZBTkd8MTQyOXw0MjB8NjUwfDI=", "the same text as UnitScan Hardcore's")
local function Channel(raw, who) M.Fire("CHAT_MSG_CHANNEL", "USHC B64:" .. codec.Encode(raw), who or "Bob-Forever", "", "5. ushccomms", "", "", 0, 5, "ushccomms") end
M.now = 2000
Channel("MOTHER FANG|1417|470|800|0")
check(M.flashed == 4 and secure.title:GetText() == "Mother Fang" and secure.sub:GetText() == "Seen close by another player",
  "close by on your map: the alert, its name to target")
M.now = 2100
Channel("GRUFF SWIFTBITE|1417|900|100|0")
check(M.flashed == 4 and Logged("Gruff Swiftbite seen by another player: Arathi Highlands 90.0, 10.0"), "further away: a line in the chat")
check(Logged("|Haddon:ClaraComboPoints:pin:1417:900:100|h"), "with a map pin to click")
for _, fn in ipairs(itemRefs) do fn(nil, "addon:ClaraComboPoints:pin:1417:900:100") end
check(M.waypoint and M.waypoint.uiMapID == 1417 and math.abs(M.waypoint.x - .9) < 1e-6, "the pin clicked: the game's map pin there")
S.map.x, S.map.y = .88, .12
M.Tick()
check(M.flashed == 5 and secure.title:GetText() == "Gruff Swiftbite", "come close to it: the alert")
M.now = 2300
Channel("NARG THE TASKMASTER|1418|470|800|0")
check(M.flashed == 5, "another map: nothing")
_G.NWB_CurrentLayer = 2
Channel("NARG THE TASKMASTER|1417|880|120|1")
check(M.flashed == 5, "NovaWorldBuffs on another layer: nothing")
Channel("NARG THE TASKMASTER|1417|880|120|2")
check(M.flashed == 6, "the same layer: the alert")
M.now = 2400
Channel("MORGAINE THE SLY|1417|880|120|2", "Lola-Forever")
check(M.flashed == 6, "your own message coming back: nothing")
M.Fire("CHAT_MSG_ADDON", "USHC", "MORGAINE THE SLY|1417|880|120|2", "GUILD", "Bob-Forever")
check(M.flashed == 7, "its guild and group messages too")
S.subzone = "Stromgarde Keep"
M.now = 2500
M.Fire("CHAT_MSG_ADDON", "USHC", "THUROS LIGHTFINGERS|1417|Stromgarde Keep|2", "PARTY", "Bob-Forever")
check(M.flashed == 8, "its older format (the subzone)")
M.Fire("CHAT_MSG_ADDON", "USHC", "KOBOLD VERMIN|1417|880|120|2", "PARTY", "Bob-Forever")
check(M.flashed == 8, "a creature not looked for: nothing")
check(#M.sent == 0 and #M.addonSent == 0, "still nothing sent")

out("== sent, when asked")
ns:SetScanOption("send", true)
M.now = 3000
S.units.nameplate8 = { name = "Fedfennel", guid = "Creature-0-4395-0-25-472-0000AB2" }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate8")
check(M.flashed == 9 and #M.sent == 0, "seen: queued, not sent yet (the game sends to a channel on a key or a click only)")
WorldFrame:GetScript("OnMouseDown")(WorldFrame, "LeftButton")
local sent = M.sent[1]
check(sent and sent[2] == "CHANNEL" and sent[3] == 3 and sent[1]:match("^USHC B64:") and codec.Decode(sent[1]:match("B64:(.+)$")) == "FEDFENNEL|1417|880|120|2",
  "a click in the world: sent in UnitScan Hardcore's format, on its channel")
_G.NWB_CurrentLayer = nil
M.now = 3200
S.units.nameplate9 = { name = "Mother Fang", guid = "Creature-0-4395-0-25-471-0000AB3" }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
WorldFrame:GetScript("OnMouseDown")(WorldFrame, "LeftButton")
check(#M.sent == 1, "no layer known (NovaWorldBuffs): nothing sent, as UnitScan Hardcore takes none")
ns:SetScanOption("send", false)
check(ClaraComboPointsDB.scan.send == nil, "unticked: back to the default, off")

out("== in a fight")
S.inCombat = true
M.now = 4000
S.units.nameplate10 = { name = "Brack", guid = "Creature-0-4395-0-25-520-0000AB4" }
local before = secure:GetAttribute("macrotext1")
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate10")
check(secure:GetAttribute("macrotext1") == before, "the secure window left alone in a fight")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(secure:IsShown() and secure:GetAttribute("macrotext1") == "/targetexact Brack\n/target [@nameplate10]", "the fight over: the window clickable")

out("== the hunted mob")
SlashCmdList.CLARACOMBOPOINTS("hunt Prince Nazjak")
check(ClaraScanHunt and ClaraScanHunt:GetAttribute("macrotext") == "/targetexact Prince Nazjak", "its key's button: /targetexact")
S.inCombat = true
SlashCmdList.CLARACOMBOPOINTS("hunt Brack")
check(ClaraScanHunt:GetAttribute("macrotext") == "/targetexact Prince Nazjak", "set in a fight: not yet")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(ClaraScanHunt:GetAttribute("macrotext") == "/targetexact Brack", "the fight over: the new one")
check(_G["BINDING_NAME_CLICK ClaraScanHunt:LeftButton"] == "Target the hunted mob (UnitScan)", "its key's name in Key Bindings")

out("== nameplates further")
ns:SetScanOption("plates", true)
check(CVARS.nameplateMaxDistance == "41", "the game's distance at its highest")
ns:SetScanOption("plates", false)
check(CVARS.nameplateMaxDistance == "20", "unticked: as it was")

out("== its page in the game's options")
local page
for _, c in ipairs(M.settingsCategories) do if c.name == "UnitScan" then page = c end end
check(page and page.parent == ns.qolThemes.quests, "UnitScan under Quests and progress, in Clara")
M.ShowSettingsPage(page)
local frame = page.frame
check(frame.rares:GetChecked() and not frame.send:GetChecked() and frame.far:GetChecked(), "rares on, sending off, far sightings on")
check((frame.rares.Text or frame.rares.text):GetText():find("488 creatures", 1, true), "the rares counted")
frame.send:Click()
check(ns:ScanOption("send") == true, "the send box: on")
frame.send:Click()
SlashCmdList.CLARACOMBOPOINTS("scan")
check(M.openedCategory == page:GetID(), "/cl scan opens it")

out("== screenshots")
M.shots = 0
M.Fire("PLAYER_LEVEL_UP", 20); Run()
check(M.shots == 1, "a level gained: a screenshot")
ns:SetLevelShots(false)
M.Fire("PLAYER_LEVEL_UP", 21); Run()
check(M.shots == 1, "its box unticked: none")
ns:SetLevelShots(true)
instance.kind = "raid"
M.Fire("ENCOUNTER_START", 610, "Razorgore", 9, 40)
M.Fire("ENCOUNTER_END", 610, "Razorgore", 9, 40, 1); Run()
check(M.shots == 2, "a raid boss's first kill: a screenshot")
M.Fire("ENCOUNTER_START", 610, "Razorgore", 9, 40)
M.Fire("ENCOUNTER_END", 610, "Razorgore", 9, 40, 1); Run()
check(M.shots == 2, "killed again: none")
M.Fire("ENCOUNTER_END", 611, "Vaelastrasz", 9, 40, 0); Run()
check(M.shots == 2, "a wipe: none")
instance.kind = "party"
M.Fire("PLAYER_ENTERING_WORLD")
S.units.boss1 = { name = "Rhahk'Zor", guid = "Creature-0-4395-0-25-644-0000AB5", level = 19 }
M.Fire("ENCOUNTER_START", 1427, "Rhahk'Zor", 1, 5)
M.Fire("ENCOUNTER_END", 1427, "Rhahk'Zor", 1, 5, 1); Run()
check(M.shots == 2, "a leveling dungeon's first boss: none")
S.units.boss1 = { name = "Edwin VanCleef", guid = "Creature-0-4395-0-25-639-0000AB6", level = 21 }
M.Fire("ENCOUNTER_START", 1429, "Edwin VanCleef", 1, 5)
M.Fire("ENCOUNTER_END", 1429, "Edwin VanCleef", 1, 5, 1); Run()
check(M.shots == 3, "its last boss: a screenshot")
S.units.boss1 = { name = "Ras Frostwhisper", guid = "Creature-0-4395-0-25-10508-0000AB7", level = 60 }
M.Fire("ENCOUNTER_START", 459, "Ras Frostwhisper", 1, 5)
M.Fire("ENCOUNTER_END", 459, "Ras Frostwhisper", 1, 5, 1); Run()
check(M.shots == 4, "a boss of a dungeon of level 54 or more: a screenshot")
S.units.boss1 = nil
S.target = { name = "Mutanus the Devourer", guid = "Creature-0-4395-0-25-3654-0000AB8", dead = true }
M.Fire("UNIT_HEALTH", "target"); Run()
check(M.shots == 5, "a last boss with no encounter of the game's, seen dead: a screenshot")
M.Fire("UNIT_HEALTH", "target"); Run()
check(M.shots == 5, "seen dead again: none")
check(ClaraComboPointsDB.bossKills["Player-1"] and ClaraComboPointsDB.bossKills["Player-1"].e610, "kept per character")

out("")
out(fails .. " failure(s)")
