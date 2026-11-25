-- Clara Combo Points - Pet feeding (a hunter's): the Feed Pet Effect on the pet, as an icon on the game's pet frame,
-- under its bars: its time left as a swipe and in seconds (as ClassicUI Forever had it on its own pet frame), its
-- tooltip on hover. With "Move the icon" on (its card's box), it is dragged to a spot of the player's (kept from the
-- pet frame's top left); a right-click puts it back. Hunters only. Where ClassicUI runs, its own icon stays (this one
-- steps aside). The game hides the pet's auras in a fight: the icon then keeps counting down from what it read last.

local ADDON, ns = ...
local L = ns.L

local FEED_SPELL = 1539                    -- Feed Pet Effect
local FEED_NAME = "Feed Pet Effect"        -- (its English name, if the client's spell name differs)
local FEED_TEXTURE = "Interface\\Icons\\Ability_Hunter_BeastTraining"
local FEED_SIZE = 20
local FEED_X, FEED_Y = 44, -37             -- its top left from the pet frame's: under its health and mana bars
local MOVER_COLOR = { 0.25, 0.6, 1, 0.45 }
local TICK = 0.1                           -- the seconds' upkeep

local issecret = issecretvalue or function() return false end
local function Secret(...)
  for i = 1, select("#", ...) do if issecret((select(i, ...))) then return true end end
  return false
end

-- Its settings, with Clara's (ClaraComboPointsDB.petFeed): its spot, its mover on
local function Store()
  local sv = ns.sv
  if not sv then return {} end
  if type(sv.petFeed) ~= "table" then sv.petFeed = {} end
  return sv.petFeed
end

local Apply = function() end
ns:SetQolSwitches("petfeed", {
  { label = "PF_SW_MOVE", get = function() return Store().unlocked == true end,
    set = function(on) Store().unlocked = on or nil Apply() end },
  -- (PetFeedText.lua: the happiness gained as floating numbers, and their zone moved: /petfeed too)
  { label = "PF_SW_TEXT", get = function() return Store().text ~= false end,
    set = function(on) if on then Store().text = nil else Store().text = false end end },
  { label = "PF_SW_TEXT_MOVE", get = function() return Store().textUnlocked == true end,
    set = function(on) Store().textUnlocked = on or nil if ns.PetFeedTextApply then ns.PetFeedTextApply() end end },
})
if not ns:QolRuns("petfeed") then return end

local feed, mover
local function Hunter()
  local _, class = UnitClass("player")
  return class == "HUNTER"
end
local function Active() return Hunter() and PetFrame ~= nil and not ns.ClassicUIRuns end

local function Place()
  if not feed then return end
  local s = Store()
  local x, y = tonumber(s.x), tonumber(s.y)
  feed:ClearAllPoints()
  feed:SetPoint("TOPLEFT", PetFrame, "TOPLEFT", x or FEED_X, y or FEED_Y)
end

-- The game hides auras from addons in a fight (and in some places): asking then is an error, not an answer
local function AurasSecret()
  local should = C_Secrets and C_Secrets.ShouldAurasBeSecret
  if not should then return false end
  local ok, secret = pcall(should)
  return not ok or Secret(secret) or secret == true
end

-- The Feed Pet Effect on the pet: its aura, false with none, nil when it cannot be told (secret, in a fight)
local function FeedAura()
  local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if not get or AurasSecret() then return nil end
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FEED_SPELL)
  for i = 1, 40 do
    local ok, aura = pcall(get, "pet", i, "HELPFUL")
    if not ok then return nil end
    if not aura then return false end
    local id, auraName = aura.spellId, aura.name
    if Secret(id, auraName) then return nil end
    if id == FEED_SPELL or (auraName ~= nil and (auraName == name or auraName == FEED_NAME)) then return aura end
  end
  return false
end

-- Feeding (PetFeedText.lua asks): true, false, nil when the game cannot tell
ns.PetFeedOn = function()
  if not (UnitExists and UnitExists("pet")) then return false end
  local aura = FeedAura()
  if aura == nil then return nil end
  return aura and true or false
end

-- Its seconds, and gone as it ends (kept up while shown)
local function Countdown(self, elapsed)
  self.wait = (self.wait or 0) - elapsed
  if self.wait > 0 then return end
  self.wait = TICK
  if not self.expires then return end
  local left = self.expires - GetTime()
  if left <= 0 then
    self.expires = nil
    self.text:SetText("")
    self.cd:Clear()
    if not (Store().unlocked == true) then self:Hide() end
    return
  end
  self.text:SetText(tostring(math.ceil(left)))
end

local function Update()
  if not feed then return end
  if not Active() then feed:Hide() return end
  local aura = UnitExists("pet") and FeedAura()
  if aura == nil then return end
  if aura then
    local duration, expires = aura.duration, aura.expirationTime
    if Secret(duration, expires, aura.icon) then return end
    feed.icon:SetTexture(aura.icon or FEED_TEXTURE)
    feed.auraInstanceID = aura.auraInstanceID
    if type(duration) == "number" and duration > 0 and type(expires) == "number" and expires > 0 then
      feed.cd:SetCooldown(expires - duration, duration)
      feed.expires = expires
      feed.wait = 0
    else
      feed.cd:Clear()
      feed.expires = nil
      feed.text:SetText("")
    end
    feed:Show()
  elseif Store().unlocked == true then
    -- (no feeding on: its icon still there while the player places it)
    feed.icon:SetTexture(FEED_TEXTURE)
    feed.auraInstanceID, feed.expires = nil, nil
    feed.cd:Clear()
    feed.text:SetText("")
    feed:Show()
  else
    feed.auraInstanceID, feed.expires = nil, nil
    feed:Hide()
  end
end
ns.PetFeedUpdate = function() Update() end -- (for the tests)

local function FeedEnter(self)
  if mover and mover:IsShown() then return end
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
  if self.auraInstanceID and GameTooltip.SetUnitBuffByAuraInstanceID then
    GameTooltip:SetUnitBuffByAuraInstanceID("pet", self.auraInstanceID, "HELPFUL")
  else
    GameTooltip:SetSpellByID(FEED_SPELL)
  end
  GameTooltip:Show()
end

-- Dragged: it follows the mouse, its spot kept as it is dropped (from the pet frame's top left, in its units)
local function Follow(self)
  local left, top = PetFrame:GetLeft(), PetFrame:GetTop()
  if not (left and top) or Secret(left, top) then return end
  local scale, frameScale = feed:GetEffectiveScale(), PetFrame:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  self.x = math.floor((cx - self.grabX - left * frameScale) / scale + 0.5)
  self.y = math.floor((cy - self.grabY - top * frameScale) / scale + 0.5)
  feed:ClearAllPoints()
  feed:SetPoint("TOPLEFT", PetFrame, "TOPLEFT", self.x, self.y)
end

local function Build()
  feed = CreateFrame("Frame", nil, PetFrame)
  feed:SetSize(FEED_SIZE, FEED_SIZE)
  feed:SetFrameLevel(PetFrame:GetFrameLevel() + 5)
  feed.icon = feed:CreateTexture(nil, "ARTWORK")
  feed.icon:SetAllPoints(feed)
  feed.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  feed.cd = CreateFrame("Cooldown", nil, feed, "CooldownFrameTemplate")
  feed.cd:SetAllPoints(feed)
  feed.cd:SetReverse(true)
  if feed.cd.SetHideCountdownNumbers then feed.cd:SetHideCountdownNumbers(true) end
  feed.text = feed:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  feed.text:SetPoint("CENTER", feed, "CENTER", 0, 0)
  feed:SetScript("OnUpdate", Countdown)
  feed:EnableMouse(true)
  feed:SetScript("OnEnter", FeedEnter)
  feed:SetScript("OnLeave", function() GameTooltip:Hide() end)
  feed:Hide()

  mover = CreateFrame("Frame", nil, feed)
  mover:SetAllPoints(feed)
  mover:SetFrameLevel(feed:GetFrameLevel() + 10)
  local tint = mover:CreateTexture(nil, "OVERLAY")
  tint:SetAllPoints(mover)
  tint:SetColorTexture(MOVER_COLOR[1], MOVER_COLOR[2], MOVER_COLOR[3], MOVER_COLOR[4])
  mover:EnableMouse(true)
  mover:RegisterForDrag("LeftButton")
  mover:SetScript("OnDragStart", function(self)
    local left, top, scale = feed:GetLeft(), feed:GetTop(), feed:GetEffectiveScale()
    if not (left and top) or Secret(left, top) then return end
    local cx, cy = GetCursorPosition()
    self.grabX, self.grabY = cx - left * scale, cy - top * scale
    self.x, self.y = nil, nil
    self:SetScript("OnUpdate", Follow)
  end)
  mover:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    if self.x and self.y then
      local s = Store()
      s.x, s.y = self.x, self.y
    end
    Place()
  end)
  mover:SetScript("OnMouseUp", function(_, button)
    if button ~= "RightButton" then return end
    local s = Store()
    s.x, s.y = nil, nil
    Place()
  end)
  mover:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.PF_MOVE_TIP, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  mover:SetScript("OnLeave", function() GameTooltip:Hide() end)
  mover:Hide()
  ns.PetFeedIcon, ns.PetFeedMover = feed, mover -- (for the tests)
end

Apply = function()
  if not Active() then
    if feed then feed:Hide() end
    return
  end
  if not feed then Build() end
  Place()
  mover:SetShown(Store().unlocked == true)
  Update()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit)
  if event == "PLAYER_LOGIN" then
    if not Hunter() then self:UnregisterAllEvents() return end
    self:RegisterUnitEvent("UNIT_AURA", "pet")
    self:RegisterUnitEvent("UNIT_PET", "player")
    self:RegisterEvent("PLAYER_REGEN_ENABLED") -- (its auras readable again)
    Apply()
    return
  end
  Update()
end)
