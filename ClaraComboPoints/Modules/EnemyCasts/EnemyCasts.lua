-- Clara Combo Points - Enemy casts (Clara's own, QoL.lua): what an enemy just did, beside its nameplate.
-- The spell it casts (its icon, its name under it), held while the cast lasts, tinted red when it is
-- interrupted; the instant ones it uses, each for a moment. The last few stay in a row (the newest by the
-- plate), each fading out after a moment. Left or right of the plate, or above it; the icons' size, how
-- many stay and how long are set on its page (Esc > Options > AddOns > Interface improvements > Enemy casts).
-- In WoW Forever a unit's casts can be secret: each plate listens to its own unit (as the game's cast
-- bars do), so the unit is never read from the event, and a secret spell ID is never read either, only
-- handed to the game, which turns it into its icon and name and draws them (C_Spell.GetSpellTexture,
-- GetSpellName, SetTexture and SetText all take secret values). Events only: nothing runs while no
-- enemy casts.

local ADDON, ns = ...
local L = ns.L

local DEFAULTS = { casts = true, instants = true, names = true, enemiesOnly = true, position = "left",
  size = 30, count = 3, hold = 3 }
local POSITIONS = { "left", "right", "above" }
local issecret = issecretvalue or function() return false end
-- (not shown, when they can be read: the auto-attacks and the shots creatures fire again and again)
local REPEATS = { [75] = true, [3018] = true, [5019] = true, [6603] = true, [6660] = true, [2764] = true,
  [2480] = true, [7918] = true, [7919] = true }

-- Its settings (ClaraComboPointsDB.enemyCasts: only what differs from the defaults is kept)
local function Get(key)
  local saved = ns.sv and ns.sv.enemyCasts
  local v = saved and saved[key]
  if v == nil then return DEFAULTS[key] end
  return v
end
local Restyle
local function Set(key, v)
  if not ns.sv then return end
  local saved = ns.sv.enemyCasts or {}
  if v == DEFAULTS[key] then saved[key] = nil else saved[key] = v end
  ns.sv.enemyCasts = next(saved) and saved or nil
  if Restyle then Restyle() end
end
ns.EnemyCastsGet, ns.EnemyCastsSet = Get, Set

---------------------------------------------------------------------------
-- Its page in the game's options, under Interface improvements
---------------------------------------------------------------------------
local function RegisterSettings()
  if not (ns.qolCategory and Settings and Settings.RegisterVerticalLayoutSubcategory
    and Settings.RegisterProxySetting and Settings.CreateCheckbox) then return end
  local ok, category = pcall(function()
    local category = Settings.RegisterVerticalLayoutSubcategory(ns.qolCategory, L.QOL_NAV_ENEMYCASTS)
    local function Register(key, label)
      return Settings.RegisterProxySetting(category, "ClaraEnemyCasts_" .. key, type(DEFAULTS[key]), label,
        DEFAULTS[key], function() return Get(key) end, function(v) Set(key, v); ns:RefreshQol() end)
    end
    local function Checkbox(key, label, tip) Settings.CreateCheckbox(category, Register(key, label), tip) end
    local function Slider(key, label, low, high, step, format)
      local options = Settings.CreateSliderOptions(low, high, step)
      options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
      Settings.CreateSlider(category, Register(key, label), options)
    end
    Checkbox("casts", L.EC_CASTS, L.EC_CASTS_TIP)
    Checkbox("instants", L.EC_INSTANTS, L.EC_INSTANTS_TIP)
    Checkbox("names", L.EC_NAMES)
    Checkbox("enemiesOnly", L.EC_ENEMIES, L.EC_ENEMIES_TIP)
    Settings.CreateDropdown(category, Register("position", L.EC_POSITION), function()
      local container = Settings.CreateControlTextContainer()
      for _, p in ipairs(POSITIONS) do container:Add(p, L["EC_POS_" .. p:upper()]) end
      return container:GetData()
    end)
    Slider("size", L.EC_SIZE, 16, 48, 1, function(v) return ("%d"):format(v) end)
    Slider("count", L.EC_COUNT, 1, 5, 1, function(v) return ("%d"):format(v) end)
    Slider("hold", L.EC_HOLD, 1, 8, 0.5, function(v) return ("%.1f s"):format(v) end)
    return category
  end)
  if ok and category then ns.enemyCastsCategory = category end
end

ns:SetQolOpener("enemycasts", function() ns:OpenSettingsTo(ns.enemyCastsCategory) end)

if not ns:QolRuns("enemycasts") then return end
RegisterSettings()

ns:SetQolSwitches("enemycasts", {
  { label = "EC_CASTS", get = function() return Get("casts") end, set = function(on) Set("casts", on) end },
  { label = "EC_INSTANTS", get = function() return Get("instants") end, set = function(on) Set("instants", on) end },
})

---------------------------------------------------------------------------
-- The icons: in a black frame, the newest with the spell's name under it
---------------------------------------------------------------------------
local rows = {} -- unit token -> its plate's icons, the newest first
local pool = {}

local function Layout(row)
  local size, where, names = Get("size"), Get("position"), Get("names")
  for i, icon in ipairs(row) do
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    if i == 1 then
      if where == "right" then
        icon:SetPoint("LEFT", row.plate, "RIGHT", 5, 0)
      elseif where == "above" then
        icon:SetPoint("BOTTOM", row.plate, "TOP", 0, 14)
      else
        icon:SetPoint("RIGHT", row.plate, "LEFT", -5, 0)
      end
    elseif where == "left" then
      icon:SetPoint("RIGHT", row[i - 1], "LEFT", -3, 0)
    else
      icon:SetPoint("LEFT", row[i - 1], "RIGHT", 3, 0)
    end
    icon.name:ClearAllPoints()
    if where == "above" then
      icon.name:SetPoint("BOTTOM", icon, "TOP", 0, 2)
    else
      icon.name:SetPoint("TOP", icon, "BOTTOM", 0, -2)
    end
    icon.name:SetShown(names and i == 1)
  end
end

local function Drop(row, icon)
  for i = #row, 1, -1 do
    if row[i] == icon then table.remove(row, i) end
  end
  icon.fade:Stop()
  icon:Hide()
  icon:ClearAllPoints()
  icon.row, icon.token = nil, nil
  pool[#pool + 1] = icon
end

local function NewIcon()
  local icon = table.remove(pool)
  if icon then return icon end
  icon = CreateFrame("Frame", nil, UIParent)
  icon.frame = icon:CreateTexture(nil, "BACKGROUND")
  icon.frame:SetPoint("TOPLEFT", -1, 1)
  icon.frame:SetPoint("BOTTOMRIGHT", 1, -1)
  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetAllPoints()
  icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon.name = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  -- held, then faded out
  icon.fade = icon:CreateAnimationGroup()
  icon.fadeOut = icon.fade:CreateAnimation("Alpha")
  icon.fadeOut:SetFromAlpha(1)
  icon.fadeOut:SetToAlpha(0)
  icon.fadeOut:SetDuration(0.5)
  icon.fade:SetScript("OnFinished", function()
    local row = icon.row
    if not row then return end
    Drop(row, icon)
    Layout(row)
  end)
  return icon
end

local function PlateOf(unit)
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or type(plate) ~= "table" or (plate.IsForbidden and plate:IsForbidden()) then return end
  local unitFrame = plate.UnitFrame
  return unitFrame and (unitFrame.healthBar or unitFrame.HealthBar) or unitFrame or plate
end

-- A spell put by the plate: held (a cast, until it ends) or fading after a moment (an instant)
local function Push(unit, spellID, held)
  local plate = PlateOf(unit)
  if not plate then return end
  local row = rows[unit]
  if not row then
    row = {}
    rows[unit] = row
  end
  row.plate = plate
  local icon = NewIcon()
  icon.row, icon.token = row, {}
  icon:SetParent(plate)
  icon:SetFrameLevel(plate:GetFrameLevel() + 10)
  icon.frame:SetColorTexture(0, 0, 0, 0.9)
  icon.texture:SetVertexColor(1, 1, 1)
  icon.name:SetTextColor(1, 0.82, 0)
  -- (a secret spell ID goes straight to the game, and what it gives back is drawn as it is)
  -- (never tested itself: a secret value is not true nor false here)
  local texture, name = C_Spell.GetSpellTexture(spellID), C_Spell.GetSpellName(spellID)
  if not issecret(texture) and texture == nil then texture = 134400 end
  if not issecret(name) and name == nil then name = "" end
  icon.texture:SetTexture(texture)
  icon.name:SetText(name)
  icon.fade:Stop()
  icon:SetAlpha(1)
  icon:Show()
  table.insert(row, 1, icon)
  while #row > Get("count") do Drop(row, row[#row]) end
  Layout(row)
  if not held then
    icon.fadeOut:SetStartDelay(Get("hold"))
    icon.fade:Play()
  end
  return icon
end

-- The held icon of a cast that ended: it fades (sooner than an instant), red if it was interrupted
local function Ended(icon, token, interrupted)
  if not icon or icon.token ~= token or not icon.row then return end
  if interrupted then
    icon.frame:SetColorTexture(0.8, 0.05, 0.05, 1)
    icon.texture:SetVertexColor(1, 0.45, 0.45)
    icon.name:SetTextColor(1, 0.25, 0.25)
  end
  if icon.fade:IsPlaying() then return end
  icon.fadeOut:SetStartDelay(math.min(1.5, Get("hold")))
  icon.fade:Play()
end

-- An enemy's plate (one the game will not say: shown)
local function Wanted(unit)
  if not Get("enemiesOnly") then return true end
  local ok, hostile = pcall(UnitCanAttack, "player", unit)
  if not ok or issecret(hostile) then return ok end
  return hostile == true
end

---------------------------------------------------------------------------
-- Each plate's unit, listened to on its own while the plate shows
---------------------------------------------------------------------------
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED",
  "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_STOP" }
local listeners = {} -- unit token -> its listener
local spare = {}

local function Readable(v) if not issecret(v) then return v end end
local function Repeated(spellID)
  local id = Readable(spellID)
  return id ~= nil and REPEATS[id] == true
end

local function OnCast(self, event, _, castGUID, spellID)
  local unit, now = self.unit, GetTime()
  if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
    Ended(self.held, self.token) -- (one still held: its end was missed)
    self.casting = event == "UNIT_SPELLCAST_START" and "cast" or "channel"
    self.guid, self.stopped, self.ended = Readable(castGUID), nil, nil
    self.held, self.token = nil, nil
    if not Get("casts") or not Wanted(unit) or Repeated(spellID) then return end
    local last = self.instant
    if self.casting == "channel" and last and last.token == self.instantToken and now - self.instantAt < 0.1 then
      -- (the channel's own success came first: its icon is held from now on)
      last.fade:Stop()
      last:SetAlpha(1)
      self.held, self.token = last, last.token
      return
    end
    self.held = Push(unit, spellID, true)
    self.token = self.held and self.held.token
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if self.casting == "channel" then return end -- (a channel's own, as it starts)
    if self.casting == "cast" then
      local guid = Readable(castGUID)
      if not (self.guid and guid) or guid == self.guid then -- (the cast's own end)
        self.casting, self.stopped = nil, now
        Ended(self.held, self.token)
        self.ended, self.endedToken, self.held = self.held, self.token, nil
        return
      end
    elseif self.stopped and now - self.stopped < 0.25 then
      return -- (the cast's own end, just after its stop)
    end
    if not Get("instants") or not Wanted(unit) or Repeated(spellID) then return end
    local icon = Push(unit, spellID, false)
    self.instant, self.instantToken, self.instantAt = icon, icon and icon.token, now
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    if self.casting ~= "channel" then return end
    self.casting = nil
    Ended(self.held, self.token)
    self.held = nil
  else -- (STOP, FAILED, INTERRUPTED: its cast's end, in whichever order they come)
    local interrupted = event ~= "UNIT_SPELLCAST_STOP"
    if self.casting == "cast" then
      self.casting, self.stopped = nil, now
      Ended(self.held, self.token, interrupted)
      self.ended, self.endedToken, self.held = self.held, self.token, nil
    elseif interrupted and self.stopped and now - self.stopped < 0.25 then
      Ended(self.ended, self.endedToken, true)
    end
  end
end

local function Listen(unit)
  local listener = listeners[unit] or table.remove(spare) or CreateFrame("Frame")
  listeners[unit] = listener
  listener.unit = unit
  listener.casting, listener.held, listener.ended, listener.stopped, listener.instant = nil, nil, nil, nil, nil
  listener:SetScript("OnEvent", OnCast)
  for _, event in ipairs(CAST_EVENTS) do listener:RegisterUnitEvent(event, unit) end
end

local function Forget(unit)
  local listener = listeners[unit]
  if listener then
    listener:UnregisterAllEvents()
    listener.casting, listener.held, listener.ended, listener.instant = nil, nil, nil, nil
    listeners[unit] = nil
    spare[#spare + 1] = listener
  end
  local row = rows[unit]
  if row then
    for i = #row, 1, -1 do Drop(row, row[i]) end
    rows[unit] = nil
  end
end

function Restyle()
  local count = Get("count")
  for _, row in pairs(rows) do
    while #row > count do Drop(row, row[#row]) end
    Layout(row)
  end
end

local plates = CreateFrame("Frame")
plates:RegisterEvent("NAME_PLATE_UNIT_ADDED")
plates:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
plates:SetScript("OnEvent", function(_, event, unit)
  if type(unit) ~= "string" or issecret(unit) then return end
  if event == "NAME_PLATE_UNIT_ADDED" then
    Forget(unit) -- (the token's last plate, if its removal was missed)
    Listen(unit)
  else
    Forget(unit)
  end
end)

ns.EnemyCasts = { rows = rows, listeners = listeners } -- (for its tests)
