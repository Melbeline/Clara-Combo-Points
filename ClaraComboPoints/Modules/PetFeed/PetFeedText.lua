-- Clara Combo Points - Pet feeding (a hunter's): each happiness tick of Feed Pet Effect as a small floating number over
-- the pet frame ("+8"; "+3.75" for the last tick, cut short as happiness tops out), rising and fading, a few gold
-- sparkles twinkling up with it as the game's drink sparkles do. The number is what the pet gained at that tick: the
-- game's own energize on the pet (UNIT_COMBAT: the number its combat log tells), set by the happiness the pet really
-- gained when the game tells it (its happiness power: the tick cut short at the top). Its zone moves: /petfeed unlocks
-- it (a box to drag; right-click: its own spot), /petfeed again locks it; its card's boxes (PetFeed.lua) do the same
-- and turn the numbers off.
-- Hunters only.

local ADDON, ns = ...
local L = ns.L
if not ns:QolRuns("petfeed") then return end

local HAPPINESS = (Enum and Enum.PowerType and Enum.PowerType.Happiness) or 27
local RISE, LIFE = 44, 1.7            -- pixels risen, seconds shown
local FADE_IN, FADE_OUT = 0.12, 0.65  -- seconds
local POP = 0.18                      -- the number's first moment, a little bigger
local FONT_SIZE = 15
local TEXT_COLOR = { 0.6, 1, 0.42 }   -- the happy face's green
local SPARK_COLOR = { 1, 0.85, 0.42 } -- gold, as the drink sparkles
local STAR = "Interface\\Cooldown\\star4"
local SPARKS = 3
local ZONE_X, ZONE_Y = 26, 6          -- the zone's centre from the pet frame's top left: over its portrait
local WAIT = 0.25                     -- seconds the game's two words on a tick (its energize, the power) are put together
local MOVER_COLOR = { 0.25, 0.6, 1, 0.35 }

local issecret = issecretvalue or function() return false end
local function Secret(...)
  for i = 1, select("#", ...) do if issecret((select(i, ...))) then return true end end
  return false
end

local function Store()
  local sv = ns.sv
  if not sv then return {} end
  if type(sv.petFeed) ~= "table" then sv.petFeed = {} end
  return sv.petFeed
end
local function On() return Store().text ~= false end

local function Hunter()
  local _, class = UnitClass("player")
  return class == "HUNTER"
end

-- The number as the combat log tells it: whole, or with its decimals (3.75), never a trailing zero
local function Format(value)
  local whole = math.floor(value + 0.5)
  if math.abs(value - whole) < 0.005 then return tostring(whole) end
  return (("%.2f"):format(value):gsub("0+$", ""):gsub("%.$", ""))
end
ns.PetFeedFormat = Format -- (for its test)

---------------------------------------------------------------------------
-- The zone, and its numbers rising
---------------------------------------------------------------------------
local zone, mover
local items = {} -- the numbers' frames, used again once faded

local function Anchor()
  return PetFrame or UIParent
end

local function Place()
  if not zone then return end
  local s = Store()
  zone:ClearAllPoints()
  zone:SetPoint("CENTER", Anchor(), "TOPLEFT", tonumber(s.textX) or ZONE_X, tonumber(s.textY) or ZONE_Y)
end

local function Animate(self, elapsed)
  self.t = self.t + elapsed
  local t, p = self.t, self.t / LIFE
  if p >= 1 then
    self:Hide()
    self:SetScript("OnUpdate", nil)
    return
  end
  local ease = 1 - (1 - p) * (1 - p) -- (fast, then slower: as the game's floating text)
  local alpha = t < FADE_IN and t / FADE_IN or (t > LIFE - FADE_OUT and (LIFE - t) / FADE_OUT or 1)
  self:ClearAllPoints()
  self:SetPoint("CENTER", zone, "CENTER", self.dx, ease * RISE)
  self:SetAlpha(alpha)
  self:SetScale(t < POP and 1 + 0.3 * (1 - t / POP) or 1)
  for i, spark in ipairs(self.sparks) do
    -- each its own way up, twinkling
    local sp = math.max(0, t - spark.delay)
    local life = LIFE - spark.delay
    local q = math.min(1, sp / life)
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", self.label, "CENTER", spark.x + spark.drift * q, spark.y + 22 * q)
    local twinkle = 0.55 + 0.45 * math.sin(sp * 9 + i * 2)
    spark:SetAlpha(sp > 0 and twinkle * (1 - q) or 0)
    if spark.SetRotation then spark:SetRotation(sp * 1.6 + i) end
  end
end

local function Item()
  for _, item in ipairs(items) do
    if not item:IsShown() then return item end
  end
  local item = CreateFrame("Frame", nil, zone)
  item:SetSize(60, 20)
  item:SetFrameStrata("MEDIUM")
  item.label = item:CreateFontString(nil, "OVERLAY")
  local font = NumberFontNormal and NumberFontNormal:GetFont() or STANDARD_TEXT_FONT
  item.label:SetFont(font, FONT_SIZE, "OUTLINE")
  item.label:SetPoint("CENTER")
  item.label:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
  item.label:SetShadowColor(0, 0, 0, 0.8)
  item.label:SetShadowOffset(1, -1)
  item.sparks = {}
  for i = 1, SPARKS do
    local spark = item:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(STAR)
    spark:SetBlendMode("ADD")
    spark:SetVertexColor(SPARK_COLOR[1], SPARK_COLOR[2], SPARK_COLOR[3])
    item.sparks[i] = spark
  end
  item:Hide()
  items[#items + 1] = item
  return item
end

local lastAt, side = 0, 1
-- One tick shown: its number rising, its sparkles with it
local function Show(value)
  if not zone or value <= 0 then return end
  local item = Item()
  item.label:SetText("+" .. Format(value))
  -- two numbers close together: side by side, not one over the other
  local now = GetTime()
  if now - lastAt < 0.45 then side = -side item.dx = 11 * side else item.dx = 0 end
  lastAt = now
  local w = math.max(18, item.label:GetStringWidth() or 18)
  for i, spark in ipairs(item.sparks) do
    local size = 9 + math.random() * 5
    spark:SetSize(size, size)
    spark.x = (i - 2) * (w / 2 + 3) + (math.random() - 0.5) * 6
    spark.y = (math.random() - 0.5) * 8
    spark.drift = (math.random() - 0.5) * 10
    spark.delay = (i - 1) * 0.1 + math.random() * 0.08
    spark:SetAlpha(0)
  end
  item.t = 0
  item:SetAlpha(0)
  item:ClearAllPoints()
  item:SetPoint("CENTER", zone, "CENTER", item.dx, 0)
  item:Show()
  item:SetScript("OnUpdate", Animate)
  ns.PetFeedLastShown = item.label:GetText() -- (for its test)
end
ns.PetFeedShow = Show

---------------------------------------------------------------------------
-- The number of a tick: the game's energize on the pet, set by the happiness it really gained
---------------------------------------------------------------------------
local last -- the pet's happiness power, as last read
local pending = {}
local waiting = false

local function Read()
  if not (UnitExists and UnitExists("pet")) then return nil end
  local ok, value = pcall(UnitPower, "pet", HAPPINESS)
  local okMax, most = pcall(UnitPowerMax, "pet", HAPPINESS)
  if not ok or type(value) ~= "number" or Secret(value) then return nil end
  if not okMax or type(most) ~= "number" or Secret(most) or most <= 0 then most = nil end
  return value, most
end

-- Feeding: the effect on the pet (true; false; nil when the game cannot tell)
local function Feeding()
  if ns.PetFeedOn then return ns.PetFeedOn() end
  return nil
end

local seen = {} -- (the mouse report: the last tick's words)
-- A tick's words put together: the happiness gained (its power), the game's number (its energize). Shown only when
-- the happiness rose, or, where its power cannot be read, while the pet is fed (another energize, its focus, is not)
local function Flush()
  waiting = false
  local amount, gained, full = pending.amount, pending.gained, pending.full
  pending = {}
  if gained == nil and amount and Read() ~= nil then
    -- (its power read but not yet told: read now)
    local value, most = Read()
    if last and value > last then gained, full = value - last, most ~= nil and value >= most end
    last = value
  end
  if not gained and not (amount and Read() == nil and Feeding() == true) then return end
  local s = Store()
  local ratio = tonumber(s.ratio) -- (the game's number for one point of happiness power, learned on a whole tick)
  if amount and gained and not full then
    ratio = amount / gained
    s.ratio = ratio
  end
  local value
  if gained and ratio then
    value = gained * ratio -- (the tick cut short at the top: what it really gave)
    if amount and not full then value = amount end
  else
    value = amount
  end
  seen.amount, seen.gained, seen.full, seen.value, seen.at = amount, gained, full, value, GetTime()
  if value and value > 0 and On() then Show(value) end
end

local function Soon()
  if waiting then return end
  waiting = true
  if C_Timer and C_Timer.After then C_Timer.After(WAIT, Flush) else Flush() end
end

local function OnPower()
  local value, most = Read()
  if not value then return end
  if last and value > last then
    pending.gained = (pending.gained or 0) + (value - last)
    pending.full = most ~= nil and value >= most
    Soon()
  end
  last = value
end

local function OnCombat(event, amount)
  if event ~= "ENERGIZE" or type(amount) ~= "number" or Secret(amount) or amount <= 0 then return end
  pending.amount = (pending.amount or 0) + amount
  Soon()
end
ns.PetFeedEvents = { Power = OnPower, Combat = OnCombat, Flush = Flush } -- (for its test)

function ns:PetFeedTextReport()
  return ("pet feeding text: shown %s, zone %s; the last tick: the game's number %s, happiness gained %s (at the top %s), shown %s, %s; one point of happiness: %s"):format(
    tostring(On()), (Store().textUnlocked and "unlocked") or "locked", tostring(seen.amount), tostring(seen.gained),
    tostring(seen.full), tostring(seen.value), seen.at and ("%.0f s ago"):format(GetTime() - seen.at) or "never",
    tostring(Store().ratio))
end

---------------------------------------------------------------------------
-- The zone moved: /petfeed
---------------------------------------------------------------------------
local function Follow(self)
  local anchor = Anchor()
  local left, top = anchor:GetLeft(), anchor:GetTop()
  if not (left and top) or Secret(left, top) then return end
  local scale, anchorScale = zone:GetEffectiveScale(), anchor:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  self.x = math.floor((cx - self.grabX) / scale - left * anchorScale / scale + 0.5)
  self.y = math.floor((cy - self.grabY) / scale - top * anchorScale / scale + 0.5)
  zone:ClearAllPoints()
  zone:SetPoint("CENTER", anchor, "TOPLEFT", self.x, self.y)
end

local function Build()
  zone = CreateFrame("Frame", "ClaraPetFeedTextZone", UIParent)
  zone:SetSize(64, 24)
  zone:SetFrameStrata("MEDIUM")
  mover = CreateFrame("Frame", nil, zone)
  mover:SetAllPoints(zone)
  mover:SetFrameLevel(zone:GetFrameLevel() + 20)
  local tint = mover:CreateTexture(nil, "BACKGROUND")
  tint:SetAllPoints(mover)
  tint:SetColorTexture(MOVER_COLOR[1], MOVER_COLOR[2], MOVER_COLOR[3], MOVER_COLOR[4])
  local sample = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sample:SetPoint("CENTER")
  sample:SetText("+8")
  mover:EnableMouse(true)
  mover:RegisterForDrag("LeftButton")
  mover:SetScript("OnDragStart", function(self)
    local scale = zone:GetEffectiveScale()
    local x, y = zone:GetCenter()
    if not (x and y) or Secret(x, y) then return end
    local cx, cy = GetCursorPosition()
    self.grabX, self.grabY = cx - x * scale, cy - y * scale
    self.x, self.y = nil, nil
    self:SetScript("OnUpdate", Follow)
  end)
  mover:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    if self.x and self.y then
      local s = Store()
      s.textX, s.textY = self.x, self.y
    end
    Place()
  end)
  mover:SetScript("OnMouseUp", function(_, button)
    if button ~= "RightButton" then return end
    local s = Store()
    s.textX, s.textY = nil, nil
    Place()
  end)
  mover:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.PF_TEXT_MOVE_TIP, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  mover:SetScript("OnLeave", function() GameTooltip:Hide() end)
  mover:Hide()
  ns.PetFeedTextZone, ns.PetFeedTextMover = zone, mover -- (for its test)
end

local function Apply()
  if not zone then return end
  Place()
  mover:SetShown(Store().textUnlocked == true)
end
ns.PetFeedTextApply = Apply

SLASH_CLARAPETFEED1 = "/petfeed"
SlashCmdList.CLARAPETFEED = function()
  if not Hunter() then return end
  if not zone then Build() end
  local s = Store()
  s.textUnlocked = (not s.textUnlocked) or nil
  Apply()
  if ns.RefreshQol then ns:RefreshQol() end -- (its card's box follows)
  if ns.Print then ns.Print(s.textUnlocked and L.PF_TEXT_UNLOCKED or L.PF_TEXT_LOCKED) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, arg2, _, arg4)
  if event == "PLAYER_LOGIN" then
    if not Hunter() then self:UnregisterAllEvents() return end
    Build()
    Apply()
    for _, e in ipairs({ "UNIT_COMBAT", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_HAPPINESS" }) do
      pcall(self.RegisterUnitEvent, self, e, "pet") -- (an event this build lacks: left out)
    end
    self:RegisterUnitEvent("UNIT_PET", "player")
    last = Read()
  elseif event == "UNIT_PET" then
    last = Read()
  elseif event == "UNIT_COMBAT" then
    OnCombat(arg2, arg4)
  else
    OnPower()
  end
end)
