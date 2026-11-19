-- Tooltip target (Modules/TooltipTarget, as TipTac shows them): in a unit's tooltip "Targeting: <<YOU>>" when it targets
-- you, else its target's name in brackets in its color; "Targeted by (n): ..." the group's members on it (alone: the
-- nameplates), you left out; both kept up to date while the tooltip shows; its two switches; Leatrix's own target line
-- steps aside; TipTac enabled: this one steps aside
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70959", "Nov 17 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }

-- The units: the mouse on a boar; the group: two members; the nameplates (alone)
local units = {
  player = { name = "Lola", player = true, class = "ROGUE" },
  mouseover = { name = "Bristleback Boar", reaction = 2 },
  party1 = { name = "Elle", player = true, class = "MAGE" },
  party2 = { name = "Piou", player = true, class = "PRIEST" },
  nameplate1 = { name = "Kobold", reaction = 2 },
}
local targets = { mouseovertarget = "player", party1target = "mouseover", party2target = nil, nameplate1target = "mouseover" }
local function Resolve(u)
  if units[u] then return u end
  local who = targets[u]
  return who
end
UnitExists = function(u) return Resolve(u) ~= nil end
UnitIsUnit = function(a, b) local x, y = Resolve(a), Resolve(b) return x ~= nil and x == y end
UnitName = function(u) local r = Resolve(u) return r and units[r] and units[r].name end
UnitIsPlayer = function(u) local r = Resolve(u) return r and units[r] and units[r].player or false end
UnitClassBase = function(u) local r = Resolve(u) return r and units[r] and units[r].class end
UnitReaction = function(u) local r = Resolve(u) return r and units[r] and units[r].reaction or 4 end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, PRIEST = { r = 1, g = 1, b = 1 }, ROGUE = { r = 1, g = 0.96, b = 0.41 } }
FACTION_BAR_COLORS = { [2] = { r = 1, g = 0, b = 0 }, [4] = { r = 1, g = 1, b = 0 } }
local inGroup = 3
GetNumGroupMembers = function() return inGroup end
IsInRaid = function() return false end
C_NamePlate = { GetNamePlates = function() return { { namePlateUnitToken = "nameplate1" } } end }

-- The game's tooltip (the parts used) and its data processor
local lines, scripts, shownTip = {}, {}, false
GameTooltip = { }
function GameTooltip:GetName() return "GameTooltip" end
function GameTooltip:GetUnit() return units.mouseover.name, "mouseover" end
function GameTooltip:NumLines() return #lines end
function GameTooltip:AddLine(t) local fs = { text = t } function fs:SetText(x) self.text = x end lines[#lines + 1] = fs; _G["GameTooltipTextLeft" .. #lines] = fs end
function GameTooltip:Show() shownTip = true end
function GameTooltip:HookScript(name, fn) scripts[name] = fn end
function GameTooltip:SetOwner() end
function GameTooltip:SetText() end
function GameTooltip:Hide() shownTip = false end
local postCalls = {}
Enum.TooltipDataType = Enum.TooltipDataType or { Unit = 2 }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = fn end }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local function Tip()
  lines = {}
  GameTooltip:AddLine("Bristleback Boar")
  for _, fn in ipairs(postCalls) do fn(GameTooltip) end
end
local function Texts() local t = {} for _, l in ipairs(lines) do t[#t + 1] = l.text end return table.concat(t, " | ") end
local function Plain(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

out("== the boar targets you; two in your group, one of them on the boar")
Tip()
local text = Plain(Texts())
check(text:find("Targeting: <<YOU>>", 1, true) ~= nil, "Targeting: <<YOU>> (" .. text .. ")")
check(Texts():find("|cffff4400<<YOU>>", 1, true) ~= nil, "<<YOU>> stands out (red)")
check(text:find("Targeted by (1): Elle", 1, true) ~= nil, "Targeted by (1): Elle")
check(Texts():find("|cff40c7ebElle", 1, true) ~= nil, "Elle in her class color")
check(not text:find("Piou", 1, true) and not text:find("Lola", 1, true), "Piou (on nothing) and you left out")

out("== kept up to date while it shows: the boar turns to Elle, Piou takes it")
targets.mouseovertarget = "party1"
targets.party2target = "mouseover"
scripts.OnUpdate(GameTooltip, 0.3)
text = Plain(Texts())
check(text:find("Targeting: [Elle]", 1, true) ~= nil, "Targeting: [Elle] (" .. text .. ")")
check(text:find("Targeted by (2): Elle, Piou", 1, true) ~= nil, "Targeted by (2): Elle, Piou")
check(#lines == 3, "the same lines written again, none added (" .. #lines .. ")")

out("== alone: the nameplates on it")
inGroup = 0
targets.mouseovertarget = "player"
Tip()
text = Plain(Texts())
check(text:find("Targeted by (1): Kobold", 1, true) ~= nil, "Targeted by (1): Kobold (" .. text .. ")")

out("== nobody on it, it targets nothing: no line")
targets.mouseovertarget = nil
targets.nameplate1target = nil
Tip()
check(#lines == 1, "only the game's lines (" .. Texts() .. ")")

out("== its switches; Leatrix's target line steps aside while this one shows it")
targets.mouseovertarget = "player"
ns.sv.tooltipTarget = { target = false }
Tip()
check(not Plain(Texts()):find("Targeting", 1, true), "its target off: no Targeting line")
check(ns:TooltipTargetShowsTarget() == false, "Leatrix's own line back then")
ns.sv.tooltipTarget = { targetedBy = false }
check(ns:TooltipTargetShowsTarget() == true, "its target on: Leatrix's own line steps aside")
local f = io.open(ADDON_DIR .. "/Modules/LeatrixPlus/Leatrix_Plus.lua", "rb")
if f then
  local src = f:read("*a"); f:close()
  check(src:find('LeaPlusLC["TipShowTarget"] == "On" and not (ClaraNS.TooltipTargetShowsTarget and ClaraNS:TooltipTargetShowsTarget())', 1, true) ~= nil,
    "Leatrix's target line asks first")
else
  out("  ok   (no Leatrix in this version)")
end
out(string.format("\n%d failure(s)", fails))
return fails
