-- Tooltip target (Modules/TooltipTarget, as TipTac shows them): in a unit's tooltip "Targeting: <<YOU>>" when it targets
-- you, else its target's name in brackets in its color; "Targeted by (n): ..." the group's members on it (alone: the
-- nameplates), you left out; both kept up to date while the tooltip shows; its two switches; Leatrix's own target line
-- steps aside; TipTac enabled: this one steps aside. Names whole ("First Surname", WoW Forever's names, whatever the
-- game's name settings hide): its lines, the tooltip's title (a title kept), Leatrix's. <<YOU>>'s color: red by default,
-- the one picked on its page (the game's color picker), or TipTac's usual white (its box, on its card and its page)
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
  player = { name = "Lola", surname = "Moon", player = true, class = "ROGUE" },
  mouseover = { name = "Bristleback Boar", reaction = 2 },
  party1 = { name = "Elle", surname = "Durand", player = true, class = "MAGE" },
  party2 = { name = "Piou", surname = "Moreau", player = true, class = "PRIEST", hidden = true }, -- (the settings hide it)
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
-- (UnitName follows the game's name settings: a surname they hide is left out; UnitNameUnmodified gives it)
UnitName = function(u) local r = Resolve(u) local x = r and units[r] if not x then return nil end return x.name, not x.hidden and x.surname or nil end
UnitNameUnmodified = function(u) local r = Resolve(u) local x = r and units[r] if not x then return nil end return x.name, x.surname end
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
check(text:find("Targeted by (1): Elle Durand", 1, true) ~= nil, "Targeted by (1): Elle Durand (her surname too)")
check(Texts():find("|cff40c7ebElle", 1, true) ~= nil, "Elle in her class color")
check(not text:find("Piou", 1, true) and not text:find("Lola", 1, true), "Piou (on nothing) and you left out")

out("== kept up to date while it shows: the boar turns to Elle, Piou takes it")
targets.mouseovertarget = "party1"
targets.party2target = "mouseover"
scripts.OnUpdate(GameTooltip, 0.3)
text = Plain(Texts())
check(text:find("Targeting: [Elle Durand]", 1, true) ~= nil, "Targeting: [Elle Durand] (" .. text .. ")")
check(text:find("Targeted by (2): Elle Durand, Piou Moreau", 1, true) ~= nil, "Targeted by (2): Elle Durand, Piou Moreau (his surname the settings hide too)")
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

out("== <<YOU>>'s color: red by default, the one picked, TipTac's white")
ns.sv.tooltipTarget = {}
targets.mouseovertarget = "player"
local function YouLine() return (ns.TooltipTargetTexts("mouseover")) or "" end
check(YouLine():find("|cffff4400<<YOU>>", 1, true) ~= nil, "red by default")
ns.sv.tooltipTarget.youColor = { 0, 1, 0 }
check(YouLine():find("|cff00ff00<<YOU>>", 1, true) ~= nil, "the color picked: green")
ns.sv.tooltipTarget.tiptacYou = true
check(YouLine():find("|cffffffff<<YOU>>", 1, true) ~= nil, "TipTac's usual color: white")
local switches = ns.qolSwitches and ns.qolSwitches.tooltiptarget or {}
local tiptacSwitch
for _, sw in ipairs(switches) do if sw.label == "TTG_TIPTAC_COLOR" then tiptacSwitch = sw end end
check(tiptacSwitch and tiptacSwitch.get() == true, "its box on the module's card too")
tiptacSwitch.set(false)
check(ns.sv.tooltipTarget.tiptacYou == nil and YouLine():find("|cff00ff00<<YOU>>", 1, true) ~= nil, "unticked on the card: the color picked back")

out("== its page: the switches, the swatch (the game's color picker), TipTac's box, the default color, a preview")
local page, parts = ns.TooltipTargetPage, ns.TooltipTargetParts
check(page ~= nil and ns.tooltipTargetCategory ~= nil, "its page, in Clara's options")
page:Show()
if page._scripts and page._scripts.OnShow then page._scripts.OnShow(page) end
check(parts.swatch and parts.tiptac and parts.reset and parts.preview and parts.target and parts.targetedBy, "its parts built")
check(Plain(parts.preview:GetText() or ""):find("Targeting: <<YOU>>", 1, true) ~= nil and (parts.preview:GetText() or ""):find("ff00ff00", 1, true) ~= nil,
  "the preview in the color picked (" .. tostring(parts.preview:GetText()) .. ")")
parts.swatch:Click()
check(ColorPickerFrame:IsShown(), "a click on the swatch: the game's color picker")
M.PickColor(0, 0, 1)
check(YouLine():find("|cff0000ff<<YOU>>", 1, true) ~= nil, "blue picked: <<YOU>> in blue")
M.PickerCancel()
check(YouLine():find("|cff00ff00<<YOU>>", 1, true) ~= nil, "Cancel: green back")
parts.tiptac:Click()
check(ns.sv.tooltipTarget.tiptacYou == true and YouLine():find("|cffffffff<<YOU>>", 1, true) ~= nil, "TipTac's box ticked: white")
check((parts.preview:GetText() or ""):find("ffffffff", 1, true) ~= nil and parts.swatch:GetAlpha() < 1, "the preview white, the swatch dimmed")
ColorPickerFrame:Hide()
parts.swatch:Click()
check(not ColorPickerFrame:IsShown(), "the swatch does nothing while TipTac's color is ticked")
parts.reset:Click()
check(ns.sv.tooltipTarget.youColor == nil and ns.sv.tooltipTarget.tiptacYou == nil and YouLine():find("|cffff4400<<YOU>>", 1, true) ~= nil,
  "Default color: red again, TipTac's box unticked")
check(not parts.tiptac:GetChecked(), "the box shown unticked")

out("== the tooltip's title: the whole name (a title kept), whatever the game's settings hide")
local function TitleOf(unit, text)
  local tip = { name = "ClaraTestTip" }
  function tip:GetName() return self.name end
  function tip:GetUnit() return "x", unit end
  local line = { text = text }
  function line:GetText() return self.text end
  function line:SetText(t) self.text = t end
  _G.ClaraTestTipTextLeft1 = line
  ns.TooltipWholeTitle(tip)
  return line.text
end
check(TitleOf("party2", "Piou") == "Piou Moreau", "Piou: Piou Moreau (the settings hid it)")
check(TitleOf("party2", "Private Piou") == "Private Piou Moreau", "a title kept: Private Piou Moreau")
check(TitleOf("party1", "Elle Durand") == "Elle Durand", "already whole: left as it is")
check(TitleOf("party2", "|cff3fc7ebPiou|r") == "|cff3fc7ebPiou Moreau|r", "colored: the color kept")
check(TitleOf("player", "Lola") == "Lola Moon", "you too: Lola Moon")
check(TitleOf("mouseover", "Bristleback Boar") == "Bristleback Boar", "a creature: left alone")
check(ns.UnitWholeName("party1") == "Elle Durand" and ns.UnitWholeName("mouseover") == "Bristleback Boar", "the whole name, for every place showing one")
if f then
  local src = io.open(ADDON_DIR .. "/Modules/LeatrixPlus/Leatrix_Plus.lua", "rb"):read("*a")
  check(src:find("if ClaraNS.UnitWholeName then nameText = ClaraNS.UnitWholeName(unit, nameText) end", 1, true) ~= nil
    and src:find("local target = ClaraNS.UnitWholeName and ClaraNS.UnitWholeName(targetUnit) or UnitName(targetUnit)", 1, true) ~= nil,
    "Leatrix's title and target line: the whole name")
end
out(string.format("\n%d failure(s)", fails))
return fails
