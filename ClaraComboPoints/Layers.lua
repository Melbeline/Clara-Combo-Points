-- Clara Combo Points - in the tooltip of the clock under the minimap: the layer you are on, and the
-- dungeons and raids entered (5 an hour, 30 a day). A creature's GUID carries the number of the
-- world copy it stands in (Creature-0-server-map-copy-npc-spawn): the copies seen on a continent,
-- in order, give the layer's number (the same way as NovaWorldBuffs; seen by this account only, so
-- a layer never met is not counted). An instance is a new one when its creatures carry a copy not
-- seen in it before (reset or not, entered again or not). The hour counts the entries of the
-- account on the realm, the day those of the character (the game's two limits). Read from the
-- target, the mouseover and the nameplates; nothing else runs.

local ADDON, ns = ...
local L = ns.L
local floor = math.floor

local HOUR, DAY = 3600, 86400
local FORGET = 6 * HOUR      -- a layer not seen for this long forgotten (the realm restarts meanwhile)
local PER_HOUR, PER_DAY = 5, 30

local realm, me
local current = {}           -- the copy last seen: map, zone, at
local pending                -- an instance just entered, its copy not yet seen
local issecret = issecretvalue or function() return false end

local function Now() return time() end

-- A creature's map and world copy
local function Creature(unit)
  local guid = UnitGUID(unit)
  if not guid or issecret(guid) then return end
  local kind, _, _, map, zone = strsplit("-", guid)
  if kind ~= "Creature" and kind ~= "Vehicle" then return end
  return tonumber(map), tonumber(zone)
end

local function Where()
  local _, kind, _, _, _, _, _, map = GetInstanceInfo()
  return map, kind
end

local function Saved()
  local sv = ns.sv
  if not sv then return end
  sv.layers = sv.layers or {}
  sv.instances = sv.instances or {}
  return sv.layers, sv.instances
end

-- The instance just entered: a new one, or one entered before (its copy already listed)
local function Settle(zone)
  local _, instances = Saved()
  if not (pending and instances) then return end
  local now = Now()
  for _, entry in ipairs(instances) do
    if entry.zone and zone and entry.zone == zone and entry.map == pending.map and now - entry.at < DAY then
      pending = nil -- (entered again)
      return
    end
  end
  instances[#instances + 1] = { at = pending.at, map = pending.map, zone = zone, name = pending.name, realm = realm, char = me }
  pending = nil
end

local function Seen(unit)
  local map, zone = Creature(unit)
  if not (map and zone) then return end
  local here, kind = Where()
  if map ~= here then return end
  if kind == "party" or kind == "raid" then
    if pending and pending.map == map then Settle(zone) end
    return
  end
  if kind ~= "none" and kind ~= nil then return end -- (battlegrounds, arenas...)
  local layers = Saved()
  if not (layers and realm) then return end
  layers[realm] = layers[realm] or {}
  local copies = layers[realm][map] or {}
  layers[realm][map] = copies
  copies[zone] = Now()
  current.map, current.zone = map, zone
end

-- What can be seen now: the target, the mouseover, the nameplates
local function Look()
  Seen("target")
  Seen("mouseover")
  if C_NamePlate and C_NamePlate.GetNamePlates then
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
      local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
      if unit then Seen(unit) end
    end
  end
end

-- The layer you are on, by its order among the ones seen on this continent; nil if not known
function ns.Layer()
  local layers = Saved()
  local here, kind = Where()
  if not (layers and realm and current.zone and current.map == here) or (kind ~= "none" and kind ~= nil) then return end
  local copies, list, now = layers[realm] and layers[realm][here], {}, Now()
  if not copies then return end
  for zone, at in pairs(copies) do
    if now - at < FORGET or zone == current.zone then list[#list + 1] = zone else copies[zone] = nil end
  end
  table.sort(list)
  for i, zone in ipairs(list) do
    if zone == current.zone then return i end
  end
end

-- The entries counted: this hour (the account, on this realm), today (this character); and when
-- the next one frees up
function ns.InstanceCounts()
  local _, instances = Saved()
  if not instances then return 0, 0 end
  local now, hour, day, oldest = Now(), 0, 0
  for i = #instances, 1, -1 do
    local entry = instances[i]
    local age = now - (entry.at or 0)
    if age >= DAY then
      table.remove(instances, i)
    else
      if age < HOUR and entry.realm == realm then
        hour = hour + 1
        if not oldest or entry.at < oldest then oldest = entry.at end
      end
      if entry.char == me and entry.realm == realm then day = day + 1 end
    end
  end
  local pendingNow = pending and 1 or 0 -- (just entered, its copy not seen yet)
  hour, day = hour + pendingNow, day + pendingNow
  if pending and (not oldest or pending.at < oldest) then oldest = pending.at end
  local frees = oldest and math.max(0, oldest + HOUR - now) or nil
  return hour, day, frees
end

-- In the clock's tooltip, under the realm and local times
local function AddLines()
  if not (ns.sv and GameTooltip) then return end
  Look()
  local layer = ns.Layer()
  local _, kind = Where()
  if layer then
    GameTooltip:AddLine(L.LAYER_N:format(layer), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
  elseif kind == "none" or kind == nil then
    GameTooltip:AddLine(L.LAYER_UNKNOWN, .6, .6, .6)
  end
  local hour, day, frees = ns.InstanceCounts()
  local color = hour >= PER_HOUR and RED_FONT_COLOR or NORMAL_FONT_COLOR
  local text = L.INSTANCES_HOUR:format(hour, PER_HOUR)
  if hour > 0 and frees then text = text .. " " .. L.INSTANCES_FREES:format(math.max(1, floor(frees / 60 + .5))) end
  GameTooltip:AddLine(text, color.r, color.g, color.b)
  local dayColor = day >= PER_DAY and RED_FONT_COLOR or NORMAL_FONT_COLOR
  GameTooltip:AddLine(L.INSTANCES_DAY:format(day, PER_DAY), dayColor.r, dayColor.g, dayColor.b)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    realm = GetRealmName and GetRealmName() or "?"
    me = (UnitName("player") or "?") .. "-" .. realm
    Saved()
    -- an instance entered before a reload, its copy not seen yet
    local kept = ns.sv and ns.sv.instancePending
    if kept and Now() - (kept.at or 0) < HOUR then pending = kept end
    if ns.sv then ns.sv.instancePending = nil end
    ns.InstanceCounts() -- (the entries older than a day dropped)
    if type(GameTime_UpdateTooltip) == "function" then hooksecurefunc("GameTime_UpdateTooltip", AddLines) end
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("PLAYER_LOGOUT")
  elseif event == "PLAYER_ENTERING_WORLD" then
    local map, kind = Where()
    if pending and pending.map ~= map then Settle(nil) end -- (left before its copy was seen: counted)
    current.map, current.zone = nil, nil
    if (kind == "party" or kind == "raid") and not pending then
      pending = { at = Now(), map = map, name = (GetInstanceInfo()) }
    end
    C_Timer.After(2, Look)
  elseif event == "PLAYER_LOGOUT" then
    if ns.sv then ns.sv.instancePending = pending end -- (a reload: still the same entry)
  elseif event == "PLAYER_TARGET_CHANGED" then
    Seen("target")
  else
    Seen("mouseover")
  end
end)
