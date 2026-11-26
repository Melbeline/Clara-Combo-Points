-- Clara Combo Points - who a unit targets and who targets it, in its tooltip, as TipTac shows them (written for Clara:
-- none of TipTac's code). "Targeting: <<YOU>>" when it targets you, else its target's name in brackets, in its class
-- color (a player) or its reaction's; "Targeted by (2): Name, Name": the members of your group targeting it (alone: the
-- units with a nameplate), each in its color. Both kept up to date while the tooltip shows (it starts or stops targeting
-- you, someone else takes it). Names whole: "First Surname" (WoW Forever's names). Its switches on its card; its page:
-- the switches, <<YOU>>'s color (red by default, any color from the game's color picker, or TipTac's usual white). TipTac
-- enabled: TipTac shows its own, this one steps aside (TipTac is never turned off). Leatrix Plus's own target line (its
-- Enhance tooltip) steps aside while this one shows it. A player's guild rank after its guild's name, "<Guild> (Rank)"
-- (a switch, on by default).

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
local function TipTacColor() return Store().tiptacYou == true end
local function ShowGuildRank() return Store().guildRank ~= false end

-- <<YOU>>'s color: red (it stands out), the one picked, or TipTac's usual white
local RED, WHITE = { 1, 0x44 / 255, 0 }, { 1, 1, 1 }
local function Picked()
  local c = Store().youColor
  if type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" then return c end
  return RED
end
local function YouColor() if TipTacColor() then return WHITE end return Picked() end

ns:SetQolSwitches("tooltiptarget", {
  { label = "TTG_SW_TARGET", get = ShowTarget, set = function(on) Store().target = on and true or false end },
  { label = "TTG_SW_TARGETEDBY", get = ShowTargetedBy, set = function(on) Store().targetedBy = on and true or false end },
  { label = "TTG_SW_GUILDRANK", get = ShowGuildRank, set = function(on) Store().guildRank = on and true or false end },
  { label = "TTG_TIPTAC_COLOR", get = TipTacColor, set = function(on) Store().tiptacYou = on and true or nil end },
})
ns:SetQolOpener("tooltiptarget", function() ns:OpenSettingsTo(ns.tooltipTargetCategory) end)

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
  local r, g, b = color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1
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
  if Same(target, "player") then return head .. "|c" .. Hex(YouColor()) .. L.TTG_YOU .. "|r" end
  local ok, name = pcall(ns.UnitWholeName, target)
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
      local ok, name = pcall(ns.UnitWholeName, who)
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

-- A player's guild rank, after its guild's name on the guild's line ("<Guild> (Rank)"); nothing when the game keeps
-- either secret
local function Plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^<", ""):gsub(">$", "")) end
local function GuildRank(tip, unit)
  if not ShowGuildRank() or Read(UnitIsPlayer, unit) ~= true or not GetGuildInfo then return end
  local ok, guild, rank = pcall(GetGuildInfo, unit)
  if not ok or issecret(guild) or issecret(rank) or type(guild) ~= "string" or guild == "" or type(rank) ~= "string" or rank == "" then return end
  local suffix = " |cffb3b3b3(" .. rank .. ")|r"
  for i = 2, math.min(tonumber(tip:NumLines()) or 0, 5) do
    local line = Line(tip, i)
    local text = line and line:GetText()
    if type(text) == "string" and not issecret(text) then
      if text:sub(-#suffix) == suffix then return end -- (written already)
      if Plain(text) == guild then
        line:SetText(text .. suffix)
        tip:Show()
        return
      end
    end
  end
end
ns.TooltipGuildRank = GuildRank -- (for its test)

local function OnUnitTip(tip)
  if tip ~= GameTooltip then return end
  local unit = TipUnit(tip)
  if not unit then shown = nil return end
  pcall(GuildRank, tip, unit)
  shown = { tip = tip, unit = unit }
  Update(shown)
end

ns.TooltipTargetTexts = function(unit) return TargetText(unit), TargetedByText(unit) end -- (for the tests)

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip) pcall(OnUnitTip, tip) end)
end

-- While it shows the same unit: written again a few times a second
local since = 0
if GameTooltip and GameTooltip.HookScript then
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
end

---------------------------------------------------------------------------
-- Its page: under its theme's page in Clara's options
---------------------------------------------------------------------------
local page = CreateFrame("Frame")
page:Hide()
local built
local updates = {}
local parts = {}
ns.TooltipTargetPage, ns.TooltipTargetParts = page, parts -- (for the tests)

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end
local function Refresh()
  for _, fn in ipairs(updates) do fn() end
  if shown then pcall(Update, shown) end
end

local function Check(key, label, y, get, set)
  local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  check:SetPoint("TOPLEFT", 10, y)
  local text = check.Text or check.text
  if text then
    text:SetFontObject("GameFontHighlight")
    text:SetText(label)
  end
  check:SetScript("OnClick", function(self)
    Click()
    set(self:GetChecked() and true or false)
    Refresh()
    if ns.RefreshOptions then ns:RefreshOptions() end
  end)
  parts[key] = check
  updates[#updates + 1] = function() check:SetChecked(get()) end
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText(L.QOL_NAV_TOOLTIPTARGET)
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)
  local hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 14, -62)
  hint:SetPoint("RIGHT", -24, 0)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetTextColor(.6, .6, .65)
  hint:SetText(L.TTG_HINT)

  Check("target", L.TTG_SW_TARGET, -100, ShowTarget, function(on) Store().target = on end)
  Check("targetedBy", L.TTG_SW_TARGETEDBY, -126, ShowTargetedBy, function(on) Store().targetedBy = on end)
  Check("guildRank", L.TTG_SW_GUILDRANK, -152, ShowGuildRank, function(on) Store().guildRank = on end)

  -- <<YOU>>'s color: its swatch (a click opens the game's color picker, Cancel puts the one before back)
  local swatch = CreateFrame("Button", nil, page)
  swatch:SetSize(22, 22)
  swatch:SetPoint("TOPLEFT", 14, -196)
  local border = swatch:CreateTexture(nil, "BACKGROUND")
  border:SetAllPoints()
  border:SetColorTexture(0.8, 0.8, 0.8, 1)
  local fill = swatch:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 2, -2)
  fill:SetPoint("BOTTOMRIGHT", -2, 2)
  local label = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
  label:SetText(L.TTG_YOU_COLOR)
  parts.swatch, parts.fill = swatch, fill
  local function Put(r, g, b)
    Store().youColor = { r, g, b }
    Refresh()
  end
  swatch:SetScript("OnClick", function()
    if TipTacColor() or not ColorPickerFrame then return end
    Click()
    local start = Picked()
    local r0, g0, b0 = start[1], start[2], start[3]
    local opening = true -- (the picker calls back while it is set up: ignored)
    ColorPickerFrame:SetupColorPickerAndShow({
      r = r0, g = g0, b = b0, hasOpacity = false,
      swatchFunc = function()
        if opening then return end
        Put(ColorPickerFrame:GetColorRGB())
      end,
      cancelFunc = function() Put(r0, g0, b0) end,
    })
    opening = false
  end)

  Check("tiptac", L.TTG_TIPTAC_COLOR, -226, TipTacColor, function(on) Store().tiptacYou = on or nil end)

  local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  reset:SetSize(200, 22)
  reset:SetPoint("TOPLEFT", 14, -262)
  reset:SetText(L.TTG_DEFAULT_COLOR)
  parts.reset = reset
  reset:SetScript("OnClick", function()
    Click()
    local st = Store()
    st.youColor, st.tiptacYou = nil, nil
    Refresh()
    if ns.RefreshOptions then ns:RefreshOptions() end
  end)

  -- What the tooltip shows
  local preview = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  preview:SetPoint("TOPLEFT", 16, -302)
  parts.preview = preview
  updates[#updates + 1] = function()
    local c = YouColor()
    fill:SetColorTexture(c[1], c[2], c[3], 1)
    local off = TipTacColor()
    swatch:SetAlpha(off and 0.4 or 1)
    label:SetAlpha(off and 0.4 or 1)
    preview:SetText(L.TTG_PREVIEW .. "  |cffffd100" .. L.TTG_TARGETING .. ":|r |c" .. Hex(c) .. L.TTG_YOU .. "|r")
  end
end

page:SetScript("OnShow", function()
  if not built then Build() end
  Refresh()
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
  local ok, category = pcall(function()
    if ns:QolCategory("tooltiptarget") and Settings.RegisterCanvasLayoutSubcategory then
      return Settings.RegisterCanvasLayoutSubcategory(ns:QolCategory("tooltiptarget"), page, L.QOL_NAV_TOOLTIPTARGET)
    end
    local c = Settings.RegisterCanvasLayoutCategory(page, L.QOL_NAV_TOOLTIPTARGET)
    Settings.RegisterAddOnCategory(c)
    return c
  end)
  if ok and category then ns.tooltipTargetCategory = category end
end
