-- The layer and the instances in the clock's tooltip (Layers.lua), the map pin on a middle click
-- (MapPin.lua), the new rank on the bars (SpellRanks.lua), the Interact Key's icons
-- (InteractKey.lua), quest progress on nameplates (QuestPlates.lua), the zone in the group finder
-- (GroupFinderZone.lua), the fishing pole (Fishing.lua), Copy Chat Message and web links (ChatCopy.lua)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false } }
local guids, instance = {}, { name = "Elwynn", kind = "none", map = 0 }
function UnitGUID(u) if u == "player" then return "Player-1-00000001" end return guids[u] end
function GetInstanceInfo() return instance.name, instance.kind, 0, "", 5, 0, false, instance.map end
function UnitIsPlayer(u) return false end
-- the clock's tooltip lines, as the game adds them
function GameTime_UpdateTooltip() GameTooltip:AddLine("Time Info") end
local CVARS = { softTargetInteract = "1", SoftTargetIconInteract = "0", SoftTargetIconGameObject = "0" }
C_CVar = { GetCVar = function(n) return CVARS[n] end, SetCVar = function(n, v) CVARS[n] = tostring(v) end }
local bindings = {}
function GetBindingKey(action) return bindings[action] end
-- action bars
local actions = {}
function GetActionInfo(slot) local a = actions[slot]; if a then return "spell", a end end
function PlaceAction(slot) local held = M.cursorSpell; M.cursorSpell = actions[slot]; actions[slot] = held end
-- the chat's menu and links
local menus = {}
Menu = { ModifyMenu = function(tag, fn) menus[tag] = fn; M.menuModifiers[tag] = M.menuModifiers[tag] or {}; table.insert(M.menuModifiers[tag], fn) end }
local filters = {}
ChatFrameUtil = { AddMessageEventFilter = function(event, fn) filters[event] = filters[event] or fn end } -- (the first: ChatCopy.lua's)
local itemRefs = {}
EventRegistry = { RegisterCallback = function(_, event, fn) itemRefs[event] = itemRefs[event] or fn end } -- (the first: ChatCopy.lua's)
COPY_CHARACTER_NAME = "Copy Character Name"
local lines = { [42] = "LFM 1 healer |cffffffff|Hitem:1|h[Sword]|h|r 5v5 yolo" }
C_ChatInfo.GetChatLineText = function(id) return lines[id] end

local NAMES = { [7620] = "Fishing", [116] = "Frostbolt", [205] = "Frostbolt", [837] = "Frostbolt", [133] = "Fireball" }
C_Spell.GetSpellName = function(id) return NAMES[id] end
local ns = {}
S.class = "MAGE"; S.locale = "enUS"
S.knownSpells = { [7620] = true, [116] = true, [205] = true, [837] = true }
S.subtexts = { [116] = "Rank 1", [205] = "Rank 2", [837] = "Rank 3" }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
Run()
local function Tooltip() GameTooltip:SetOwner(UIParent); GameTime_UpdateTooltip(); return table.concat(GameTooltip._lines, " | ") end
-- the portrait's menu with the game's "Reset all instances": the tooltip that entry gets
RESET_INSTANCES = "Reset all instances"
local function InstanceTip()
  local root = MenuUtil.CreateFrame()
  local reset = root:CreateButton(RESET_INSTANCES)
  for _, fn in ipairs(M.menuModifiers.MENU_UNIT_SELF) do fn(UIParent, root, {}) end
  if not reset.tooltip then return "" end
  GameTooltip:SetOwner(UIParent)
  reset.tooltip(GameTooltip, reset)
  return table.concat(GameTooltip._lines, " | ")
end

out("== the layer")
check(Tooltip():find("Layer: unknown", 1, true), "no creature seen yet: the layer unknown")
guids.target = "Creature-0-4395-0-25-299-0000ABC"
M.Fire("PLAYER_TARGET_CHANGED")
check(Tooltip():find("Layer 1", 1, true), "a creature targeted: Layer 1 (the only copy seen)")
guids.mouseover = "Creature-0-4395-0-12-80-0000DEF"
M.Fire("UPDATE_MOUSEOVER_UNIT")
check(Tooltip():find("Layer 1", 1, true), "another, of a lower copy: that one is Layer 1 now")
guids.target, guids.mouseover = "Creature-0-4395-0-25-299-0000ABC", nil -- (the mouse on the clock now)
M.Fire("PLAYER_TARGET_CHANGED")
check(Tooltip():find("Layer 2", 1, true), "back to the first copy: Layer 2 of 2")
guids.target = "Player-1-0000002"; guids.mouseover = nil
M.Fire("PLAYER_TARGET_CHANGED")
check(Tooltip():find("Layer 2", 1, true), "a player targeted: nothing changes")
guids.target = "Creature-0-4395-1-40-299-0000ABC"
M.Fire("PLAYER_TARGET_CHANGED")
check(Tooltip():find("Layer 2", 1, true), "a creature of another continent (shown on its map only): nothing changes here")

out("== the instances")
check(InstanceTip():find("^Reset all instances | ") ~= nil, "in the tooltip of the portrait menu's Reset all instances")
check(not Tooltip():find("Instances", 1, true), "no longer in the clock's tooltip (its layer only)")
check(InstanceTip():find("Instances: 0/5 this hour", 1, true) and InstanceTip():find("Today: 0/30", 1, true), "none entered: 0/5, 0/30")
instance.name, instance.kind, instance.map = "Deadmines", "party", 36
guids.target = nil
M.Fire("PLAYER_ENTERING_WORLD"); Run()
check(InstanceTip():find("Instances: 1/5 this hour", 1, true), "entered: 1/5 at once")
guids.target = "Creature-0-4395-36-777-1-0000"
M.Fire("PLAYER_TARGET_CHANGED")
check(#ClaraComboPointsDB.instances == 1 and ClaraComboPointsDB.instances[1].zone == 777, "its copy seen: one entry, that copy")
-- out and in again: the same copy, not counted again
instance.name, instance.kind, instance.map = "Westfall", "none", 0
M.Fire("PLAYER_ENTERING_WORLD"); Run()
instance.name, instance.kind, instance.map = "Deadmines", "party", 36
M.Fire("PLAYER_ENTERING_WORLD"); Run()
M.Fire("PLAYER_TARGET_CHANGED")
check(#ClaraComboPointsDB.instances == 1 and InstanceTip():find("1/5", 1, true), "entered again, same copy: still 1")
-- reset: a new copy
instance.name, instance.kind, instance.map = "Westfall", "none", 0
M.Fire("PLAYER_ENTERING_WORLD"); Run()
instance.name, instance.kind, instance.map = "Deadmines", "party", 36
guids.target = nil -- (no target kept through a loading screen)
M.Fire("PLAYER_ENTERING_WORLD"); Run()
guids.target = "Creature-0-4395-36-901-1-0000"
M.Fire("PLAYER_TARGET_CHANGED")
check(#ClaraComboPointsDB.instances == 2 and InstanceTip():find("2/5", 1, true), "reset, a new copy: 2/5")
check(InstanceTip():find("one frees up in 60 min", 1, true), "when the oldest frees up")
-- an hour later: the hour empty, the day not
M.now = (M.now or 0) + 3601
check(InstanceTip():find("Instances: 0/5", 1, true) and InstanceTip():find("Today: 2/30", 1, true), "an hour later: 0/5, the day 2/30")
M.now = M.now + 86400
InstanceTip()
check(#ClaraComboPointsDB.instances == 0, "a day later: forgotten")

out("== the map pin")
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame.ScrollContainer = CreateFrame("Frame", nil, WorldMapFrame)
function WorldMapFrame.ScrollContainer:GetCursorPosition() return 100, 50 end
function WorldMapFrame.ScrollContainer:NormalizeUIPosition() return .4, .6 end
function WorldMapFrame:GetMapID() return 1429 end
local pins = {}
function WorldMapFrame:EnumeratePinsByTemplate() local i = 0; return function() i = i + 1; return pins[i] end end
local pinHandler
function WorldMapFrame:AddGlobalPinMouseActionHandler(fn) pinHandler = fn end
MapCanvasMixin = { MouseAction = { Up = 1, Down = 2, Click = 3 } }
local waypoint, tracked
C_Map = { CanSetUserWaypointOnMap = function(id) return id == 1429 end, SetUserWaypoint = function(p) waypoint = p end,
  ClearUserWaypoint = function() waypoint = nil end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) tracked = on end }
UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
M.Fire("ADDON_LOADED", "Blizzard_WorldMap")
local up = WorldMapFrame.ScrollContainer:GetScript("OnMouseUp")
up(WorldMapFrame.ScrollContainer, "LeftButton")
check(waypoint == nil, "a left click: the game's own")
up(WorldMapFrame.ScrollContainer, "MiddleButton")
check(waypoint and waypoint.map == 1429 and waypoint.x == .4 and waypoint.y == .6 and tracked == true, "a middle click: the game's pin there, tracked")
pins[1] = { IsMouseOver = function() return true end }
check(pinHandler and pinHandler(WorldMapFrame, 1, "MiddleButton") == true, "a middle click on a pin: ours")
check(waypoint == nil and tracked == false, "on the map pin itself: taken off")

out("== the new rank on the bars")
actions = { [1] = 205, [2] = 116, [5] = 205, [7] = 133 }
S.knownSpells[837] = true
M.cursorSpell = nil
ns:SpellLearned(837); Run()
check(actions[1] == 837 and actions[5] == 837, "rank 3 learned: the buttons of rank 2 (the highest until then) take it")
check(actions[2] == 116, "rank 1 (a downrank put there on purpose): left alone")
check(actions[7] == 133 and M.cursorSpell == nil, "another spell untouched, the cursor empty")
actions[1] = 205
ns:SpellLearned(837); Run() -- (the game telling the same learning again: its chat line)
M.Fire("SPELLS_CHANGED"); Run()
check(actions[1] == 205, "only when learned: a rank 2 put back afterwards stays")

out("== the Interact Key's icons")
check(CVARS.SoftTargetIconInteract == "0", "the game's key off: nothing set")
CVARS.softTargetInteract = "3"; M.Fire("CVAR_UPDATE", "softTargetInteract")
check(CVARS.SoftTargetIconInteract == "0", "on but not bound: nothing yet")
bindings.INTERACTTARGET = "NUMPADDECIMAL"; M.Fire("UPDATE_BINDINGS")
check(CVARS.SoftTargetIconInteract == "1" and CVARS.SoftTargetIconGameObject == "1", "on and bound: the icons over its target")
ns:SetInteractIcons(false)
check(CVARS.SoftTargetIconInteract == "0" and CVARS.SoftTargetIconGameObject == "0", "the box off: given back")
ns:SetInteractIcons(true)
CVARS.softTargetInteract = "1"; M.Fire("CVAR_UPDATE", "softTargetInteract")
check(CVARS.SoftTargetIconInteract == "0", "the game's key turned off: given back")

out("== quest progress on nameplates")
local plates = {}
C_NamePlate = { GetNamePlateForUnit = function(u) return plates[u] end, GetNamePlates = function()
  local t = {} for _, p in pairs(plates) do t[#t + 1] = p end return t end }
local tips = {}
C_TooltipInfo.GetUnit = function(u) return tips[u] end
plates.nameplate1 = CreateFrame("Frame", nil, UIParent); plates.nameplate1.namePlateUnitToken = "nameplate1"
plates.nameplate2 = CreateFrame("Frame", nil, UIParent); plates.nameplate2.namePlateUnitToken = "nameplate2"
tips.nameplate1 = { lines = { { type = 0, leftText = "Boar" }, { type = 17, leftText = "Bad Boars" }, { type = 8, leftText = "Boar Ribs: 3/8", completed = false } } }
tips.nameplate2 = { lines = { { type = 0, leftText = "Wolf" } } }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
local mark = plates.nameplate1.claraQuest
check(mark and mark:IsShown() and mark.text:GetText() == "3/8", "a creature of a quest: its mark and 3/8")
check(not plates.nameplate2.claraQuest, "another: nothing")
tips.nameplate1.lines[3].completed = true
M.Fire("QUEST_LOG_UPDATE"); Run()
check(not mark:IsShown(), "the objective done: the mark goes")
tips.nameplate1.lines[3].completed = false
ns:SetQuestPlates(false)
check(not mark:IsShown(), "the box off: no marks")
ns:SetQuestPlates(true)
check(mark:IsShown(), "on again: back")

out("== the zone in the group finder")
local leaders = { [5] = { name = "Schakklin", areaName = "Shattrath City" }, [6] = { name = "Kemael" } }
C_LFGList = { GetSearchResultLeaderInfo = function(id) return leaders[id] end }
function LFGBrowseSearchEntry_Update(entry) end
M.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
local entry = CreateFrame("Button", nil, UIParent)
entry.PartyIcon = entry:CreateTexture(); entry.PartyIcon:SetPoint("TOPLEFT", entry, "TOPLEFT", 8, -14)
entry.ActivityName = entry:CreateFontString(); entry.NameMaxWidth = 228
entry.resultID = 5
LFGBrowseSearchEntry_Update(entry)
local zone = entry.claraZone
local _, _, _, ix, iy = entry.PartyIcon:GetPoint(1)
check(zone and zone:IsShown() and zone:GetText() == "Shattrath City", "the leader's zone on a line under the activity")
check(ix == 8 and iy == -7, "the name and the activity lifted for the three lines")
entry.resultID = 6
LFGBrowseSearchEntry_Update(entry)
_, _, _, ix, iy = entry.PartyIcon:GetPoint(1)
check(not zone:IsShown() and iy == -14, "no zone given: the row as the game has it")
entry.resultID = 5
ns:SetGroupFinderZone(false)
LFGBrowseSearchEntry_Update(entry)
check(not zone:IsShown(), "the box off: nothing added")
ns:SetGroupFinderZone(true)

out("== the fishing pole")
local bags = { [0] = { [3] = { itemID = 6256 } } }
C_Container = { GetContainerNumSlots = function(bag) return bags[bag] and 16 or 0 end,
  GetContainerItemInfo = function(bag, slot) return bags[bag] and bags[bag][slot] end }
local itemKind = { [6256] = { 2, 20 }, [2131] = { 2, 7 }, [2132] = { 4, 6 } }
C_Item.GetItemInfoInstant = function(item)
  local id = tonumber(type(item) == "string" and item:match("item:(%d+)") or item)
  local k = itemKind[id]; if k then return id, "", "", "", 0, k[1], k[2] end
end
local equipped = {}
C_Item.EquipItemByName = function(item, slot) equipped[#equipped + 1] = { item, slot } end
S.inventory = { [16] = 2131, [17] = 2132 }
M.Fire("SPELLS_CHANGED")
local fish = ClaraFishingButton
check(fish:GetAttribute("type") == "macro" and fish:GetAttribute("macrotext") == "/equip item:6256", "no pole in hand: the key equips the one in the bags")
S.inventory = { [16] = 6256 }
M.Fire("PLAYER_EQUIPMENT_CHANGED", 16)
check(fish:GetAttribute("type") == "spell", "the pole in hand: the key fishes")
ns:SetFishingMode(true); ns:SetFishingMode(false); Run()
check(#equipped == 2 and equipped[1][1]:find("item:2131") and equipped[1][2] == 16 and equipped[2][1]:find("item:2132") and equipped[2][2] == 17,
  "fishing mode turned off: the weapons back in hand")

out("== copying from the chat")
local root = { items = {} }
function root:EnumerateElementDescriptions() return ipairs(self.items) end
function root:Insert(d, at) if at then table.insert(self.items, at, d) else table.insert(self.items, d) end end
for _, t in ipairs({ "Agrodealer", "Interact", "Whisper", "Other Options", "Ignore", "Report Player", "Copy Character Name" }) do
  root:Insert({ text = t })
end
menus.MENU_UNIT_FRIEND(UIParent, root, { lineID = 42, name = "Agrodealer" })
local names = {} for i, d in ipairs(root.items) do names[i] = d.text end
check(names[7] == "Copy Chat Message" and names[8] == "Copy Character Name", "shorter than Copy Character Name: just before it")
local copy = root.items[7]
copy.callback()
local box = ClaraChatCopyBox
check(box and box:IsShown() and box.edit:GetText() == "LFM 1 healer [Sword] 5v5 yolo", "a click: that line's message, without its markup, in the box")
box:Hide()
-- longer than Copy Character Name: last
ns.L.COPY_CHAT_MESSAGE = "Copy this whole chat message here"
root.items = {}
for _, t in ipairs({ "Report Player", "Copy Character Name", "Report AFK" }) do root:Insert({ text = t }) end
menus.MENU_UNIT_FRIEND(UIParent, root, { lineID = 42 })
check(root.items[#root.items].text == "Copy this whole chat message here", "longer than Copy Character Name: last")
root.items = {}
menus.MENU_UNIT_FRIEND(UIParent, root, {})
check(#root.items == 0, "a name with no chat line (the friends list): nothing added")
-- web addresses
local discard, text = filters.CHAT_MSG_CHANNEL(nil, "CHAT_MSG_CHANNEL", "Raid Helper (https://discord.gg/pABDHHaMQr) and www.example.com.", "Goldo")
check(discard == false and text:find("|Haddon:ClaraComboPoints:url:https://discord.gg/pABDHHaMQr|h[https://discord.gg/pABDHHaMQr]|h", 1, true)
  and text:find("(", 1, true) and text:find(")", 1, true), "an address in brackets: a link, the brackets kept outside")
check(text:find("|Haddon:ClaraComboPoints:url:www.example.com|h", 1, true) and text:sub(-1) == ".", "www.: a link, the full stop outside")
local _, kept = filters.CHAT_MSG_CHANNEL(nil, "CHAT_MSG_CHANNEL", "|cffffffff|Hitem:1|h[http://x.y/z]|h|r no address")
check(kept == nil, "no address outside the links: the message left as it is")
itemRefs.SetItemRef(nil, "addon:ClaraComboPoints:url:https://discord.gg/pABDHHaMQr")
check(box:IsShown() and box.edit:GetText() == "https://discord.gg/pABDHHaMQr", "a click on one: the address in the box")
out("")
out(fails .. " failure(s)")
