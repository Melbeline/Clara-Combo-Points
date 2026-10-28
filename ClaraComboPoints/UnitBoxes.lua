-- Clara Combo Points - two boxes over the game's target and focus frames, in Era's look (the box
-- of its threat percent: the border, the colored fill, the number):
--   the threat percent in a fight, as the game reads it (your share of the unit's threat, or your
--   lead while it attacks you), in the threat color; the game shows its own only with the
--   threatShowNumeric setting, hidden while this one shows. A box in the game's options
--   (Esc > Options > AddOns > Clara Combo Points) turns it off.
--   the distance to an enemy, from WeaponSwingTimer's range bands ("8-15 m"), in their colors;
--   on by default for a hunter, ticked or not in WeaponSwingTimer's options (Range) or on its page
--   of Clara's window. None while WeaponSwingTimer is not built in.
-- The two side by side over the name bar; the threat alone in the game's place while the distance
-- is off. The distance's box is wider (its band and unit, "15-35 m"), the same art drawn longer: its
-- ends as drawn, its straight middle stretched. On ClassicUI's frames, ClassicUI's threat percent
-- and a distance box in its art (Modules/ClassicUI/Units/ClaraUnitBoxes.lua).

local ADDON, ns = ...
local L = ns.L

local BOX_W, BOX_H, FILL_W, FILL_H, FILL_Y, TEXT_Y = 49, 18, 37, 14, -3, -4 -- (the game's own)
local RANGE_W = 66 -- the distance's box
local GAP = 6
local TEX_W, TEX_H = 64, 32 -- (the border's file; its ends 9 wide, its middle from 9 to 40)
local END_W = 9
local BORDER = "Interface\\TargetingFrame\\NumericThreatBorder"
local FILL = "Interface\\TargetingFrame\\UI-StatusBar"
local BORDER_COORDS = { 0, 0.765625, 0, 0.5625 }
local TICK = 0.2 -- the distance read again
local FRAMES = { target = "TargetFrame", focus = "FocusFrame" }
local UNITS = { "target", "focus" }

local function Secret(v) return issecretvalue and issecretvalue(v) end

function ns:ThreatBox() return not self.sv or self.sv.threatBox ~= false end

---------------------------------------------------------------------------
-- The boxes
---------------------------------------------------------------------------
local boxes = { threat = {}, range = {} }

-- The game's pieces of a frame: where its name bar is, where its own threat box sits
local function Parts(unit)
  local frame = _G[FRAMES[unit]]
  local content = frame and frame.TargetFrameContent
  local main = content and content.TargetFrameContentMain
  local contextual = content and content.TargetFrameContentContextual
  if not (main and main.ReputationColor and contextual) then return nil end
  return main.ReputationColor, contextual
end

-- The threat box as the game draws it; width: longer, its border in three (ends, middle stretched)
local function NewBox(parent, width)
  local box = CreateFrame("Frame", nil, parent)
  width = width or BOX_W
  box:SetSize(width, BOX_H)
  box.fill = box:CreateTexture(nil, "BACKGROUND")
  box.fill:SetTexture(FILL)
  box.fill:SetSize(width - (BOX_W - FILL_W), FILL_H)
  box.fill:SetPoint("TOP", box, "TOP", 0, FILL_Y)
  if width == BOX_W then
    box.border = box:CreateTexture(nil, "ARTWORK")
    box.border:SetTexture(BORDER)
    box.border:SetTexCoord(unpack(BORDER_COORDS))
    box.border:SetAllPoints(box)
  else
    local bottom = BORDER_COORDS[4]
    local pieces = { { 0, END_W / TEX_W, "TOPLEFT" }, { (BOX_W - END_W) / TEX_W, BOX_W / TEX_W, "TOPRIGHT" } }
    box.ends = {}
    for i, p in ipairs(pieces) do
      local t = box:CreateTexture(nil, "ARTWORK")
      t:SetTexture(BORDER)
      t:SetTexCoord(p[1], p[2], 0, bottom)
      t:SetSize(END_W, BOX_H)
      t:SetPoint(p[3], box, p[3])
      box.ends[i] = t
    end
    box.border = box:CreateTexture(nil, "ARTWORK") -- (the middle)
    box.border:SetTexture(BORDER)
    box.border:SetTexCoord(END_W / TEX_W, (BOX_W - END_W) / TEX_W, 0, bottom)
    box.border:SetPoint("TOPLEFT", box.ends[1], "TOPRIGHT")
    box.border:SetPoint("BOTTOMRIGHT", box.ends[2], "BOTTOMLEFT")
  end
  box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  box.text:SetPoint("TOP", box, "TOP", 0, TEXT_Y)
  box:Hide()
  return box
end

-- WeaponSwingTimer's range, when built in, and whether its box is wanted
local function Range()
  local wst = ns.WST
  if wst and wst.RangeBand and wst.RangeBoxOn and wst.RangeBoxOn() then return wst end
end

-- ClassicUI's distance box, when that frame is its (it shows the threat percent itself, placed
-- beside the distance while that is on)
local function ClassicBox(unit)
  local cui = ns.ClassicUIPrivate
  return cui and cui.ClaraRangeBox and cui.ClaraRangeBox(unit, Range() ~= nil)
end

local function SetShown(box, show)
  if box and box:IsShown() ~= show then box:SetShown(show) end
end

-- The game's frame boxes, made the first time; placed again as the distance goes on or off. None
-- (and ours hidden) on ClassicUI's frame.
local placed = {}
local function Base(unit)
  local bar, contextual = Parts(unit)
  if not bar then return nil end
  if ClassicBox(unit) then
    SetShown(boxes.threat[unit], false)
    SetShown(boxes.range[unit], false)
    return nil
  end
  local threat, range = boxes.threat[unit], boxes.range[unit]
  if not threat then
    threat, range = NewBox(contextual), NewBox(contextual, RANGE_W)
    boxes.threat[unit], boxes.range[unit] = threat, range
  end
  local pair = Range() ~= nil
  if placed[unit] ~= pair then
    placed[unit] = pair
    threat:ClearAllPoints()
    threat:SetPoint("BOTTOM", bar, "TOP", pair and -(GAP + RANGE_W) / 2 or 0, 0)
    range:ClearAllPoints()
    range:SetPoint("BOTTOM", bar, "TOP", (BOX_W + GAP) / 2, 0)
  end
  return threat, range, contextual.NumericalThreat
end

---------------------------------------------------------------------------
-- The threat percent (the game's reading, UnitFrame_UpdateThreatIndicator)
---------------------------------------------------------------------------
local function Threat(unit)
  if not (UnitExists(unit) and not UnitIsDead(unit) and UnitClassification(unit) ~= "minus") then return nil end
  if not (UnitDetailedThreatSituation and GetThreatStatusColor) then return nil end
  local tanking, status, _, raw = UnitDetailedThreatSituation("player", unit)
  local value = raw
  if tanking and not Secret(tanking) and UnitThreatPercentageOfLead then value = UnitThreatPercentageOfLead("player", unit) end
  if value == nil or status == nil or Secret(value) or Secret(status) or value == 0 then return nil end
  return value, status
end

local gameFaded = {}
local function UpdateThreat(unit)
  local threat, _, game = Base(unit)
  if not threat then return end -- (ClassicUI's frame: its own threat percent)
  local on = ns:ThreatBox()
  -- the game's own box out of sight while ours is on (both in the same place)
  if game and (on or gameFaded[unit]) then
    gameFaded[unit] = on or nil
    game:SetAlpha(on and 0 or 1)
  end
  local value, status = nil, nil
  if on then value, status = Threat(unit) end
  if value then
    threat.text:SetFormattedText("%1.0f%%", value)
    threat.fill:SetVertexColor(GetThreatStatusColor(status))
  end
  SetShown(threat, value ~= nil)
end

---------------------------------------------------------------------------
-- The distance (WeaponSwingTimer_Range.lua: the bands, their colors)
---------------------------------------------------------------------------
local function Label(box, short)
  if box.short == short and box.lang == ns.lang then return end
  box.short, box.lang = short, ns.lang
  box.text:SetText(short .. " " .. L.RANGE_UNIT)
  if box.text:GetStringWidth() > box:GetWidth() - (BOX_W - FILL_W) then box.text:SetText(short) end -- (no room for the unit)
end

-- Shown or hidden; true while the unit is there to be read again
local function UpdateRange(unit)
  local classic = ClassicBox(unit)
  local box = classic
  if not classic then
    local _, range = Base(unit)
    box = range
  end
  if not box then return false end
  local wst = Range()
  local short, key, r, g, b
  if wst and UnitExists(unit) then short, key, r, g, b = wst.RangeBand(unit) end
  if short then
    Label(box, short)
    box.fill:SetVertexColor(r or .65, g or .65, b or .65)
  end
  SetShown(box, short ~= nil)
  if classic and ns.ClassicUIPrivate.ClaraRangeShown then ns.ClassicUIPrivate.ClaraRangeShown(unit, short ~= nil) end
  return wst ~= nil and UnitExists(unit)
end

local driver = CreateFrame("Frame")
driver:Hide()
local wait = 0
driver:SetScript("OnUpdate", function(self, elapsed)
  wait = wait - elapsed
  if wait > 0 then return end
  wait = TICK
  local watching = false
  for _, unit in ipairs(UNITS) do
    if UpdateRange(unit) then watching = true end
  end
  if not watching then self:Hide() end -- (nothing to read: woken by a new target or focus)
end)

local function WakeRange()
  wait = 0
  driver:Show()
end

---------------------------------------------------------------------------
-- Everything again: a new target or focus, a setting changed
---------------------------------------------------------------------------
local function Refresh()
  for _, unit in ipairs(UNITS) do
    UpdateThreat(unit)
    UpdateRange(unit)
  end
  WakeRange()
end
ns.RefreshUnitBoxes = Refresh

function ns:SetThreatBox(on)
  if on then self.sv.threatBox = nil else self.sv.threatBox = false end
  Refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    if not (_G.TargetFrame or _G.FocusFrame) then return end
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
      self:RegisterEvent(e)
    end
    pcall(self.RegisterUnitEvent, self, "UNIT_THREAT_LIST_UPDATE", "target", "focus")
    pcall(self.RegisterUnitEvent, self, "UNIT_THREAT_SITUATION_UPDATE", "player", "target") -- (the player's standing)
    if ns.WST then ns.WST.OnRangeBoxChanged = Refresh end -- (its box ticked or unticked)
    Refresh()
  elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
    UpdateThreat("target")
    UpdateThreat("focus")
  else
    Refresh()
  end
end)
