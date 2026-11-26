-- Clara Combo Points - Pet feeding (a hunter's): each happiness tick of Feed Pet Effect as a small floating number over
-- the pet frame ("+8"; "+3.75" for the last tick, cut short as happiness tops out), rising and fading, a few gold
-- sparkles twinkling up with it as the game's drink sparkles do. The number is what the pet gained at that tick: the
-- game's own energize on the pet (UNIT_COMBAT: the number its combat log tells). WoW 12 gives that number to addons
-- as a secret: shown as the game gives it (never read), while the pet is fed. Where it comes readable, it is set by
-- the happiness the pet really gained when the game tells it (its happiness power: the tick cut short at the top). Its zone moves: /petfeed unlocks
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
-- (value: a number of ours, or the game's own, secret: shown as the game gives it, never read)
local function Show(value)
  if not zone or value == nil then return end
  local secret = Secret(value)
  if not secret and value <= 0 then return end
  local item = Item()
  if secret then
    if not pcall(item.label.SetFormattedText, item.label, "+%s", value) then
      if not pcall(item.label.SetText, item.label, value) then return end
    end
  else
    item.label:SetText("+" .. Format(value))
  end
  -- two numbers close together: side by side, not one over the other
  local now = GetTime()
  if now - lastAt < 0.45 then side = -side item.dx = 11 * side else item.dx = 0 end
  lastAt = now
  local w = item.label:GetStringWidth()
  if Secret(w) or type(w) ~= "number" then w = 30 end -- (a secret text's width is secret too)
  w = math.max(18, w)
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

-- (the mouse report: what the game told, to see in game where a tick comes from)
local diag = { combat = 0, feedback = 0, kinds = {}, secretKinds = 0, power = 0, powerKinds = {}, happy = 0, reg = {} }
local function Kinds(t)
  local out = {}
  for k, n in pairs(t) do out[#out + 1] = k .. " " .. n end
  table.sort(out)
  return #out > 0 and table.concat(out, ", ") or "none"
end

local function Read()
  if not (UnitExists and UnitExists("pet")) then diag.read = "no pet" return nil end
  local ok, value = pcall(UnitPower, "pet", HAPPINESS)
  local okMax, most = pcall(UnitPowerMax, "pet", HAPPINESS)
  if not ok then diag.read = "refused: " .. tostring(value) return nil end
  if Secret(value) then diag.read = "secret" return nil end
  if type(value) ~= "number" then diag.read = "not a number: " .. type(value) return nil end
  diag.read = "read"
  if not okMax or type(most) ~= "number" or Secret(most) or most <= 0 then most = nil end
  return value, most
end

-- Feeding: the effect on the pet (true; false; nil when the game cannot tell)
local function Feeding()
  if ns.PetFeedOn then return ns.PetFeedOn() end
  return nil
end

local seen = { ticks = 0, secrets = 0 } -- (the mouse report: the last tick's words)
-- A tick's words put together: the happiness gained (its power), the game's number (its energize). Shown only when
-- the happiness rose, or, where its power cannot be read, while the pet is fed (another energize, its focus, is not)
local function Flush()
  waiting = false
  local amount, gained, full, secret = pending.amount, pending.gained, pending.full, pending.secret
  pending = {}
  if secret ~= nil then
    -- The game gives its number to addons as a secret (WoW 12's UNIT_COMBAT): shown as it is, the combat log's own
    -- number (the tick cut short at the top too: the game's), never read; while the pet is fed, or its happiness rose
    if gained == nil and Read() ~= nil then
      local value, most = Read()
      if last and value > last then gained, full = value - last, most ~= nil and value >= most end
      last = value
    end
    local fed = Feeding()
    seen.amount, seen.gained, seen.full, seen.at, seen.fed = "the game's (secret)", gained, full, GetTime(), fed
    if not ((gained and gained > 0) or fed == true) then seen.value = "not shown (not fed)" return end
    seen.value = "the game's number"
    if On() then Show(secret) end
    return
  end
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
  seen.amount, seen.gained, seen.full, seen.value, seen.at, seen.fed = amount, gained, full, value, GetTime(), nil
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

-- (from: "combat", the event UNIT_COMBAT; "feedback", the game's own number on the pet's portrait)
local function OnCombat(event, amount, from)
  from = from or "combat"
  diag[from] = diag[from] + 1
  if Secret(event) then
    -- (its kind unreadable: an energize taken only while the pet is fed)
    diag.secretKinds = diag.secretKinds + 1
    if Feeding() ~= true then return end
  else
    local kind = tostring(event)
    diag.kinds[kind] = (diag.kinds[kind] or 0) + 1
    if kind ~= "ENERGIZE" then return end
  end
  if amount == nil then return end
  seen.ticks = seen.ticks + 1
  if Secret(amount) then
    seen.secrets = seen.secrets + 1
    pending.secret = amount -- (the latest: one number shown a tick)
    Soon()
    return
  end
  if type(amount) ~= "number" or amount <= 0 then return end
  pending.amount = (pending.amount or 0) + amount
  Soon()
end
ns.PetFeedEvents = { Power = OnPower, Combat = OnCombat, Flush = Flush } -- (for its test)

function ns:PetFeedTextReport()
  local power, most = Read()
  local fed = Feeding()
  local regs = {}
  for e, r in pairs(diag.reg) do regs[#regs + 1] = e .. " " .. r end
  table.sort(regs)
  return ("pet feeding text: shown %s, zone %s; energizes on the pet %d (secret %d); the last tick: the game's number %s, happiness gained %s (at the top %s), fed %s, shown %s, %s; one point of happiness: %s; happiness power now %s / %s (%s)\n"
    .. "    the game told: UNIT_COMBAT on the pet %d, the portrait's own numbers %d (kinds: %s; unreadable kinds %d), its power %d (%s), UNIT_HAPPINESS %d; fed now %s; registered: %s; last error: %s"):format(
    tostring(On()), (Store().textUnlocked and "unlocked") or "locked", seen.ticks, seen.secrets, tostring(seen.amount),
    tostring(seen.gained), tostring(seen.full), tostring(seen.fed), tostring(seen.value),
    seen.at and ("%.0f s ago"):format(GetTime() - seen.at) or "never", tostring(Store().ratio), tostring(power), tostring(most),
    tostring(diag.read), diag.combat, diag.feedback, Kinds(diag.kinds), diag.secretKinds, diag.power, Kinds(diag.powerKinds),
    diag.happy, tostring(fed), #regs > 0 and table.concat(regs, ", ") or "nothing", tostring(diag.err or "none"))
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
local function OnEvent(self, event, unit, arg2, _, arg4)
  if event == "PLAYER_LOGIN" then
    if not Hunter() then self:UnregisterAllEvents() return end
    for _, e in ipairs({ "UNIT_COMBAT", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_HAPPINESS" }) do
      local ok, err = pcall(self.RegisterUnitEvent, self, e, "pet") -- (an event this build lacks: left out)
      diag.reg[e] = ok and "ok" or ("refused: " .. tostring(err))
    end
    self:RegisterUnitEvent("UNIT_PET", "player")
    -- the game's own number on the pet's portrait (its PetFrame, on UNIT_COMBAT): the same tick, from the game's side
    if type(CombatFeedback_OnCombatEvent) == "function" then
      hooksecurefunc("CombatFeedback_OnCombatEvent", function(frame, kind, _, amount)
        if frame ~= PetFrame then return end
        local ok, err = pcall(OnCombat, kind, amount, "feedback")
        if not ok then diag.err = tostring(err) end
      end)
      diag.reg.feedback = "ok"
    end
    Build()
    Apply()
    last = Read()
  elseif event == "UNIT_PET" then
    last = Read()
  elseif event == "UNIT_COMBAT" then
    OnCombat(arg2, arg4, "combat")
  else
    if event == "UNIT_HAPPINESS" then
      diag.happy = diag.happy + 1
    else
      diag.power = diag.power + 1
      local kind = Secret(arg2) and "secret" or tostring(arg2)
      diag.powerKinds[kind] = (diag.powerKinds[kind] or 0) + 1
    end
    OnPower()
  end
end
events:SetScript("OnEvent", function(...)
  local ok, err = pcall(OnEvent, ...)
  if not ok then diag.err = tostring(err) end
end)
