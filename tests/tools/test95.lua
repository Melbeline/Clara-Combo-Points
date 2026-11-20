-- The zone on a character's tooltip's last line (AltFriends.lua), wherever the tooltip shows (over the world, a party
-- or target frame): a group member's from the game's map for that member (a cave's map: its zone's; a dungeon: the
-- dungeon), else the group's roster by its whole name only (two Charlottes: each her own, never guessed by a first
-- name); one in sight: yours; one of Clara's list online: its own Clara's word; one's own: yours; never twice
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local postCall
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) if kind == "unit" then postCall = fn end end }
Enum.TooltipDataType = { Unit = "unit" }
Enum.UIMapType = { Zone = 3, Dungeon = 4, Micro = 5 }
WorldFrame = WorldFrame or CreateFrame("Frame", "WorldFrame")
-- the units: party1 Elle Woods (also under the mouse), party2 Charlotte Moon, party3 Charlotte Elle; a stranger
-- targeted nearby; Bob Twink (of Clara's list) as focus, far away
local units = { player = { "Lola", "Brume" }, party1 = { "Elle", "Woods" }, mouseover = { "Elle", "Woods" },
  party2 = { "Charlotte", "Moon" }, party3 = { "Charlotte", "Elle" }, target = { "Randy", "Rando" }, focus = { "Bob", "Twink" } }
function UnitName(u) local x = units[u] if x then return x[1], x[2] end end
UnitNameUnmodified = UnitName
function UnitIsPlayer(u) return units[u] ~= nil end
function UnitIsUnit(a, b)
  local x, y = units[a], units[b]
  return a == b or (x ~= nil and y ~= nil and x[1] == y[1] and x[2] == y[2])
end
local visible = { player = true, target = true, mouseover = true }
function UnitIsVisible(u) return visible[u] == true end
function GetRealZoneText() return "Elwynn Forest" end
function IsInGroup() return true end
function IsInRaid() return false end
local roster = { { "Lola", "Elwynn Forest" }, { "Elle", "Duskwood" }, { "Charlotte", "Thendal Village" }, { "Charlotte", "Orgrimmar" } }
function GetNumGroupMembers() return #roster end
function GetRaidRosterInfo(i) local r = roster[i] return r[1], 0, 1, 13, "Hunter", "HUNTER", r[2] end
-- the game's maps for each group member
local mapOf = { party1 = 1434 }
local maps = { [1434] = { name = "Stranglethorn Vale", mapType = 3 }, [2000] = { name = "Zul'Gurub Gate", mapType = 5, parentMapID = 1434 },
  [90] = { name = "Gnomeregan", mapType = 4 } }
C_Map = C_Map or {}
C_Map.GetBestMapForUnit = function(u) return mapOf[u] end
C_Map.GetMapInfo = function(id) return maps[id] end

local tipUnit
function GameTooltip:GetOwner() return self._owner end
function GameTooltip:GetUnit() return "?", tipUnit end
function GameTooltip:NumLines() return #self._lines end
function GameTooltip:GetName() return "GameTooltip" end
setmetatable(_G, { __index = function(_, k)
  local i = type(k) == "string" and tonumber(k:match("^GameTooltipTextLeft(%d+)$"))
  if i then return { GetText = function() return GameTooltip._lines[i] end } end
end })
local function Hover(owner, unit, lines)
  GameTooltip:SetOwner(owner)
  GameTooltip._lines = lines or { "Name", "Level 13 Hunter", "Alliance" }
  tipUnit = unit
  postCall(GameTooltip, {})
  return GameTooltip._lines
end
local function Zone(owner, unit) local lines = Hover(owner, unit) return #lines == 4 and lines[4] or nil end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
ns.sv.altFriends = { ["bob twink"] = { name = "Bob Twink" } }
M.Fire("PLAYER_LOGIN")
check(postCall ~= nil, "the unit tooltips heard")
local partyFrame = CreateFrame("Button", "TestPartyFrame", UIParent)

out("== a group member: the game's map for that member, on the tooltip's last line")
check(Zone(partyFrame, "party1") == "Stranglethorn Vale", "over its party frame: " .. tostring(Zone(partyFrame, "party1")))
check(Zone(UIParent, "mouseover") == "Stranglethorn Vale", "over the world (its party token found): " .. tostring(Zone(UIParent, "mouseover")))
mapOf.party1 = 2000
check(Zone(partyFrame, "party1") == "Stranglethorn Vale", "in a cave or a building: its zone's")
mapOf.party1 = 90
check(Zone(partyFrame, "party1") == "Gnomeregan", "in a dungeon: the dungeon")
local lines = Hover(partyFrame, "party1", { "Elle Woods", "Level 13 Hunter", "Alliance", "Gnomeregan" })
check(#lines == 4, "shown already: not twice")

out("== the map not told (a restricted place): the group's roster, by its whole name only")
mapOf.party1 = nil
visible.mouseover = nil
check(Zone(partyFrame, "party1") == nil, "the roster giving its first name alone: none guessed")
roster[2][1] = "Elle-Woods"
check(Zone(partyFrame, "party1") == "Duskwood", "the roster's First-Surname: its zone")
out("== two of the same first name: each her own, never the other's")
check(Zone(partyFrame, "party2") == nil and Zone(partyFrame, "party3") == nil, "the roster's first names alone: none guessed")
roster[3][1] = "Charlotte-Moon"; roster[4][1] = "Charlotte Elle"
check(Zone(partyFrame, "party2") == "Thendal Village" and Zone(partyFrame, "party3") == "Orgrimmar", "each by her whole name")

out("== one in sight, not grouped: yours (it is right there)")
check(Zone(UIParent, "target") == "Elwynn Forest", "the stranger nearby: Elwynn Forest")
check(Zone(partyFrame, "player") == "Elwynn Forest", "your own tooltip: yours")

out("== one of Clara's list, far away: its own Clara's word, once online")
check(Zone(partyFrame, "focus") == nil, "Bob: nothing known yet")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|20|WARRIOR|Westfall", "WHISPER", "Bob Twink")
check(Zone(partyFrame, "focus") == "Westfall", "Bob: Westfall, from his Clara")
out(string.format("\n%d failure(s)", fails))
return fails
