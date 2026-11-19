-- Clara Combo Points - who a unit targets and who targets it, in its tooltip, as TipTac shows them (written for Clara:
-- none of TipTac's code). "Targeting: <<YOU>>" when it targets you, else its target's name in brackets, in its class
-- color (a player) or its reaction's; "Targeted by (2): Name, Name": the members of your group targeting it (alone: the
-- units with a nameplate), each in its color. Both kept up to date while the tooltip shows (it starts or stops targeting
-- you, someone else takes it). Its two switches on its card. TipTac enabled: TipTac shows its own, this one steps aside
-- (TipTac is never turned off). Leatrix Plus's own target line (its Enhance tooltip) steps aside while this one shows it.

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end
local EVERY = 0.2 -- seconds between two updates while the tooltip shows

local function Store()
  local sv = ns.sv
  if type(sv) ~= "table" then return {} end
  if type(sv.tooltipTarget) ~= "table" then sv.tooltipTarget = {} end
  return sv.tooltipTarget
end
local function ShowTarget() return Store().target ~= false end
local function ShowTargetedBy() return Store().targetedBy ~= false end

ns:SetQolSwitches("tooltiptarget", {
  { label = "TTG_SW_TARGET", get = ShowTarget, set = function(on) Store().target = on and true or false end },
  { label = "TTG_SW_TARGETEDBY", get = ShowTargetedBy, set = function(on) Store().targetedBy = on and true or false end },
})

-- (for Leatrix Plus: its own target line steps aside while this one shows the target)
function ns:TooltipTargetShowsTarget() return false end
if not ns:QolRuns("tooltiptarget") then return end
function ns:TooltipTargetShowsTarget() return ShowTarget() end

-- A value read safely: nil when the call fails or the game keeps it secret
local function Read(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if ok and value ~= nil and not issecret(value) then return value end
  return nil
end

local function Same(a, b)
  if C_Secrets and C_Secrets.CanCompareUnitTokens and not Read(C_Secrets.CanCompareUnitTokens, a, b) then return false end
  return Read(UnitIsUnit, a, b) == true
end

local function Hex(color)
  if type(color) ~= "table" then return "ffffffff" end
  local r, g, b = color.r or 1, color.g or 1, color.b or 1
  return ("ff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- A unit's color: its class's (a player), else its reaction's to you
local function ColorOf(unit)
  if Read(UnitIsPlayer, unit) then
    local class = Read(UnitClassBase, unit) or Read(function(u) return (select(2, UnitClass(u))) end, unit)
    if type(class) == "string" then
      local color = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
      if color then return color end
    end
  end
  local reaction = Read(UnitReaction, unit, "player")
  return (reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]) or HIGHLIGHT_FONT_COLOR
end

-- (a name may be secret: only joined to the text, never read)
local function Painted(color, name) return "|c" .. Hex(color) .. name .. "|r" end

-- "Targeting: <<YOU>>" / "Targeting: [Name]", or nil
local function TargetText(unit)
  local target = unit .. "target"
  if not Read(UnitExists, target) then return nil end
  local head = "|cffffd100" .. L.TTG_TARGETING .. ":|r "
  if Same(target, "player") then return head .. "|cffff4400" .. L.TTG_YOU .. "|r" end
  local ok, name = pcall(UnitName, target)
  if not ok or name == nil then return nil end
  local color = ColorOf(target)
  return head .. Painted(color, "[") .. Painted(color, name) .. Painted(color, "]")
end

-- The group's members on it (alone: the units with a nameplate), you left out
local function Watchers()
  local units = {}
  local count = Read(GetNumGroupMembers) or 0
  if count > 0 then
    local raid = Read(IsInRaid)
    for i = 1, count do units[#units + 1] = raid and ("raid" .. i) or ("party" .. i) end
  elseif C_NamePlate and C_NamePlate.GetNamePlates then
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    for _, plate in ipairs(ok and type(plates) == "table" and plates or {}) do
      local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
      if type(token) == "string" and not issecret(token) then units[#units + 1] = token end
    end
  end
  return units
end

-- "Targeted by (2): Name, Name", or nil
local function TargetedByText(unit)
  local names = {}
  for _, who in ipairs(Watchers()) do
    if Read(UnitExists, who) and not Same(who, "player") and Same(who .. "target", unit) then
      local ok, name = pcall(UnitName, who)
      if ok and name ~= nil then names[#names + 1] = Painted(ColorOf(who), name) end
    end
  end
  if #names == 0 then return nil end
  local text = names[1]
  for i = 2, #names do text = text .. "|cffffffff, |r" .. names[i] end
  return "|cffffd100" .. L.TTG_TARGETED_BY .. " (|r|cffffffff" .. #names .. "|r|cffffd100):|r " .. text
end

---------------------------------------------------------------------------
-- In the tooltip: its lines added once, then written again in place
---------------------------------------------------------------------------
local shown -- { tip, unit, targetLine, byLine }

local function TipUnit(tip)
  local ok, _, unit = pcall(tip.GetUnit, tip)
  if ok and type(unit) == "string" and not issecret(unit) then return unit end
  return nil
end

local function Line(tip, index)
  local name = tip:GetName()
  return name and _G[name .. "TextLeft" .. index]
end

-- One of its lines: written again where it is, or added (the tooltip then fitted to it)
local function Put(rec, key, text)
  local tip = rec.tip
  local index = rec[key]
  if index then
    local line = Line(tip, index)
    if line then line:SetText(text or "") end
    return false
  end
  if not text then return false end
  tip:AddLine(" ")
  rec[key] = tip:NumLines()
  local line = Line(tip, rec[key])
  if line then line:SetText(text) end
  return true
end

local function Update(rec)
  local unit = rec.unit
  local grew = false
  if ShowTarget() then grew = Put(rec, "targetLine", TargetText(unit)) or grew end
  if ShowTargetedBy() then grew = Put(rec, "byLine", TargetedByText(unit)) or grew end
  if grew then rec.tip:Show() end
end

local function OnUnitTip(tip)
  if tip ~= GameTooltip then return end
  local unit = TipUnit(tip)
  if not unit then shown = nil return end
  shown = { tip = tip, unit = unit }
  Update(shown)
end

ns.TooltipTargetTexts = function(unit) return TargetText(unit), TargetedByText(unit) end -- (for the tests)

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip) pcall(OnUnitTip, tip) end)
end

-- While it shows the same unit: written again a few times a second
local since = 0
if not (GameTooltip and GameTooltip.HookScript) then return end
GameTooltip:HookScript("OnUpdate", function(tip, elapsed)
  local rec = shown
  if not rec or rec.tip ~= tip then return end
  since = since + (elapsed or 0)
  if since < EVERY then return end
  since = 0
  if TipUnit(tip) ~= rec.unit then return end
  pcall(Update, rec)
end)
GameTooltip:HookScript("OnHide", function() shown = nil end)
