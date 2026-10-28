local _, ClaraNS = ... -- (Clara Combo Points: ClassicUI Forever built in, QoL.lua)
if not (type(ClaraNS) == "table" and ClaraNS.ClassicUIRuns) then return end
local ns = ClaraNS.ClassicUIPrivate
local L = ns.L

-- The hunter's pet frame, two icons by it (Clara Combo Points): the Feed Pet Effect on the pet under its bars, its time
-- left as a swipe and in seconds (as the pet's target frame has it, without targeting the pet); and the game's happiness
-- face, 9 nearer the frame than the game sets it. With Move the pet's icons on, either is dragged to a spot of the
-- player's (kept from the pet frame's top left); a right-click puts it back. Only while our pet frame is in force: the
-- face goes back to the game's spot without it.

local FEED_SPELL = 1539                    -- Feed Pet Effect
local FEED_NAME = "Feed Pet Effect"        -- (its English name, if the client's spell differs)
local FEED_TEXTURE = "Interface\\Icons\\Ability_Hunter_BeastTraining"
local FEED_SIZE = 24
local FEED_X, FEED_Y = 41, -46             -- its top left from the pet frame's: under the bars
local FACE_SHIFT = -9                      -- the happiness face: 9 left of the game's spot
local FEED_KEYS, FACE_KEYS = { "petFeedX", "petFeedY" }, { "petFaceX", "petFaceY" }
local MOVER_COLOR = { 0.25, 0.6, 1, 0.45 }
local TICK = 0.1                           -- the seconds' upkeep

local feed, face, gameSpot, faceTaken
local movers = {}
local active = false

local function Hunter()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

-- A spot the player dragged an icon to, from the pet frame's top left (nil: its own).
local function Spot(keys)
    local x, y = tonumber(ns.db[keys[1]]), tonumber(ns.db[keys[2]])
    if x and y then return x, y end
end

local function PlaceFace()
    face = face or _G.PetFrameHappiness
    if not face then return end
    if not gameSpot then
        local point, rel, relPoint, x, y = face:GetPoint(1)
        if not point or ns.AnySecret(point, rel, relPoint, x, y) or type(x) ~= "number" or type(y) ~= "number" then return end
        gameSpot = { point, rel, relPoint, x, y }
    end
    local g = gameSpot
    if not active then
        if faceTaken then ns.SetPointIf(face, g[1], g[2], g[3], g[4], g[5]) end
        faceTaken = false
        return
    end
    faceTaken = true
    local x, y = Spot(FACE_KEYS)
    if x then
        ns.SetPointIf(face, "TOPLEFT", PetFrame, "TOPLEFT", x, y)
    else
        ns.SetPointIf(face, g[1], g[2], g[3], g[4] + FACE_SHIFT, g[5])
    end
end

local function PlaceFeed()
    if not feed then return end
    local x, y = Spot(FEED_KEYS)
    ns.SetPointIf(feed, "TOPLEFT", PetFrame, "TOPLEFT", x or FEED_X, y or FEED_Y)
end

-- The game hides auras from addons in a fight (and in some places): asking then is an error, not an answer.
local function AurasSecret()
    local should = C_Secrets and C_Secrets.ShouldAurasBeSecret
    if not should then return false end
    local ok, secret = pcall(should)
    return not ok or ns.AnySecret(secret) or secret == true
end

-- The Feed Pet Effect on the pet: its aura, false with none, nil when it cannot be told (secret, in a fight).
local function FeedAura()
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get or AurasSecret() then return nil end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FEED_SPELL)
    for i = 1, 40 do
        local ok, aura = pcall(get, "pet", i, "HELPFUL")
        if not ok then return nil end
        if not aura then return false end
        local id, auraName = aura.spellId, aura.name
        if ns.AnySecret(id, auraName) then return nil end
        if id == FEED_SPELL or (auraName ~= nil and (auraName == name or auraName == FEED_NAME)) then return aura end
    end
    return false
end

-- Its seconds, and gone as it ends (kept up while shown).
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
        if not (active and ns.db.petIconsUnlocked == true) then self:Hide() end
        return
    end
    self.text:SetText(tostring(math.ceil(left)))
end

local function UpdateFeed()
    if not feed then return end
    if not (active and ns.db.petFeedIcon ~= false) then
        feed:Hide()
        return
    end
    local aura = UnitExists("pet") and FeedAura()
    if aura == nil then return end
    if aura then
        local duration, expires = aura.duration, aura.expirationTime
        if ns.AnySecret(duration, expires, aura.icon) then return end
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
    elseif ns.db.petIconsUnlocked == true then
        -- No feeding on: its icon still there while the player places it.
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

local function FeedEnter(self)
    if movers[self] and movers[self]:IsShown() then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    if self.auraInstanceID and GameTooltip.SetUnitBuffByAuraInstanceID then
        GameTooltip:SetUnitBuffByAuraInstanceID("pet", self.auraInstanceID, "HELPFUL")
    else
        GameTooltip:SetSpellByID(FEED_SPELL)
    end
    GameTooltip:Show()
end

-- Dragging an icon: it follows the mouse, its spot kept as it is dropped (from the pet frame's top left, in its units).
local function Follow(self)
    local icon = self.icon
    local left, top = PetFrame:GetLeft(), PetFrame:GetTop()
    if not (left and top) then return end
    local scale, frameScale = icon:GetEffectiveScale(), PetFrame:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    self.x = math.floor((cx - self.grabX - left * frameScale) / scale + 0.5)
    self.y = math.floor((cy - self.grabY - top * frameScale) / scale + 0.5)
    ns.SetPointIf(icon, "TOPLEFT", PetFrame, "TOPLEFT", self.x, self.y)
end

local function Mover(icon, keys, place)
    local mover = CreateFrame("Frame", nil, icon)
    mover:SetAllPoints(icon)
    mover:SetFrameLevel(icon:GetFrameLevel() + 10)
    local tint = mover:CreateTexture(nil, "OVERLAY")
    tint:SetAllPoints(mover)
    tint:SetColorTexture(MOVER_COLOR[1], MOVER_COLOR[2], MOVER_COLOR[3], MOVER_COLOR[4])
    mover.icon = icon
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function(self)
        local left, top, scale = icon:GetLeft(), icon:GetTop(), icon:GetEffectiveScale()
        if not (left and top) then return end
        local cx, cy = GetCursorPosition()
        self.grabX, self.grabY = cx - left * scale, cy - top * scale
        self.x, self.y = nil, nil
        self:SetScript("OnUpdate", Follow)
    end)
    mover:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.x and self.y then ns.db[keys[1]], ns.db[keys[2]] = self.x, self.y end
        place()
    end)
    mover:SetScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" then return end
        ns.db[keys[1]], ns.db[keys[2]] = nil, nil
        place()
    end)
    mover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["PET_ICON_MOVE_TIP"], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    mover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mover:Hide()
    movers[icon] = mover
    return mover
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
    Mover(feed, FEED_KEYS, PlaceFeed)
    face = face or _G.PetFrameHappiness
    if face then Mover(face, FACE_KEYS, PlaceFace) end
end

local auraEvents, petEvents, fightEvents
local function Apply()
    if not (Hunter() and PetFrame and ns.db) then return end
    active = ns.ModuleInForce("unitFramePet") == true
    if active and not feed then Build() end
    PlaceFace()
    PlaceFeed()
    UpdateFeed()
    local unlocked = active and ns.db.petIconsUnlocked == true
    for _, mover in pairs(movers) do mover:SetShown(unlocked) end
    if active and not auraEvents then
        auraEvents = ns.EventFrame({ "UNIT_AURA" }, UpdateFeed, "pet")
        petEvents = ns.EventFrame({ "UNIT_PET" }, function()
            PlaceFace()
            UpdateFeed()
        end, "player")
        fightEvents = ns.EventFrame({ "PLAYER_REGEN_ENABLED" }, UpdateFeed) -- (its auras readable again)
    elseif not active and auraEvents then
        auraEvents:UnregisterAllEvents()
        petEvents:UnregisterAllEvents()
        fightEvents:UnregisterAllEvents()
        auraEvents, petEvents, fightEvents = nil, nil, nil
    end
end
ns.PetIconsApply = Apply -- (for the tests)

local KEYS = { petFeedIcon = true, petIconsUnlocked = true, unitFrames = true, unitFramePet = true }
ns.OnToggle(function(key) if KEYS[key] then Apply() end end)
ns.EventFrame("PLAYER_LOGIN", Apply)
