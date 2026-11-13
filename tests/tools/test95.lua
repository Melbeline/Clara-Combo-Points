-- The zone in a character's tooltip over a frame (AltFriends.lua): a group member's from the group's roster, else a
-- character of Clara's list online from its own Clara's answer; not over the world, not twice, not for oneself
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local postCall
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) if kind == "unit" then postCall = fn end end }
Enum.TooltipDataType = { Unit = "unit" }
WorldFrame = WorldFrame or CreateFrame("Frame", "WorldFrame")
local units = { party1 = { "Elle", "Woods" }, party2 = { "Bob", "Twink" }, mouseover = { "Elle", "Woods" } }
function UnitName(u) local x = units[u] if x then return x[1], x[2] end if u == "player" then return "Lola" end end
function UnitIsPlayer(u) return units[u] ~= nil end
function UnitIsUnit(a, b) return a == b end
local roster = { { "Lola", "Elwynn Forest" }, { "Elle", "Stranglethorn Vale" } }
function GetNumGroupMembers() return #roster end
function GetRaidRosterInfo(i) local r = roster[i] return r[1], 0, 1, 13, "Hunter", "HUNTER", r[2] end
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

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
ns.sv.altFriends = { ["bob twink"] = { name = "Bob Twink" } }
M.Fire("PLAYER_LOGIN")
check(postCall ~= nil, "the unit tooltips heard")
local partyFrame = CreateFrame("Button", "TestPartyFrame", UIParent)

out("== a group member over its party frame: the roster's zone")
local lines = Hover(partyFrame, "party1")
check(lines[#lines] == "Stranglethorn Vale" and #lines == 4, "Elle: Stranglethorn Vale added (" .. tostring(lines[#lines]) .. ")")
lines = Hover(partyFrame, "party1", { "Elle Woods", "Level 13 Hunter", "Stranglethorn Vale" })
check(#lines == 3, "the game shows it already: not twice")

out("== over the world: nothing added")
lines = Hover(UIParent, "mouseover")
check(#lines == 3, "the character is right there")

out("== a character of the list, not grouped: its own Clara's zone, once online")
lines = Hover(partyFrame, "party2")
check(#lines == 3, "Bob: no zone known yet")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|20|WARRIOR|Westfall", "WHISPER", "Bob Twink")
lines = Hover(partyFrame, "party2")
check(lines[#lines] == "Westfall", "Bob: Westfall, from his Clara")
out(string.format("\n%d failure(s)", fails))
return fails
