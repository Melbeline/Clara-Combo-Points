-- Clara Combo Points - in the tooltip of the clock under the minimap: the layer you are on; in the
-- tooltip of "Reset all instances" (the portrait's menu): the dungeons and raids entered (5 an hour,
-- 30 a day). A creature's GUID carries the number of the
-- world copy it stands in (Creature-0-server-map-copy-npc-spawn): the copies seen on a continent,
-- in order, give the layer's number (the same way as NovaWorldBuffs; seen by this account only, so
-- a layer never met is not counted). An instance is a new one when its creatures carry a copy not
-- seen in it before (reset or not, entered again or not). The hour counts the entries of the
-- account on the realm, the day those of the character (the game's two limits). Read from the
-- target, the mouseover and the nameplates; nothing else runs.
-- WoW 12.1.7 (and WoW Forever's 1.60.1 hotfix) hides the realm, server and spawn in creatures' GUIDs: their
-- world copy may then be no copy at all. Seen so (not a number; three copies at once; more than four new ones in
-- five minutes on one map), the layer is "hidden by the game" for the session, never a wrong one, and a dungeon
-- entered again can no longer be told: each entry then counts.

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
local NEW_WINDOW, NEW_MAX = 300, 4 -- (more new copies than this in that many seconds: not copies)
local hidden = false         -- the game hides the copies (kept for this game build: sv.layerHidden)
local fresh = {}             -- [map] = { [zone] = first seen this session }
local function Build() return GetBuildInfo and tostring((select(2, GetBuildInfo()))) or "?" end
-- The copies are no copies: none read any more with this build, the ones kept (scrambled) dropped
local function Hide()
  hidden = true
  current.map, current.zone = nil, nil
  if ns.sv then
    ns.sv.layerHidden = Build()
    ns.sv.layers = {}
  end
end

local function Now() return time() end

-- A creature's map and world copy
local function Creature(unit)
  local guid = UnitGUID(unit)
  if not guid or issecret(guid) then return end
  local kind, _, _, map, zone, _, spawn = strsplit("-", guid)
  if kind ~= "Creature" and kind ~= "Vehicle" then return end
  map, zone = tonumber(map), tonumber(zone)
  if spawn and not (map and zone) and not hidden then Hide() end -- (a creature's GUID, its copy no number: hidden)
  return map, zone
end

-- Too many new copies on one map, too fast for players changing layers: the game scrambles them
local function Scrambled(map, zone)
  local seen = fresh[map] or {}
  fresh[map] = seen
  if seen[zone] then return false end
  local now, recent = Now(), 0
  seen[zone] = now
  for _, at in pairs(seen) do if now - at < NEW_WINDOW then recent = recent + 1 end end
  return recent > NEW_MAX
end
function ns.LayerHidden() return hidden end

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
  if hidden then
    if pending and map and pending.map == map then Settle(nil) end -- (counted: entered again or not, unknown)
    return
  end
  if not (map and zone) then return end
  local here, kind = Where()
  if map ~= here then return end
  if kind == "party" or kind == "raid" then
    if pending and pending.map == map then Settle(zone) end
    return map, zone
  end
  if kind ~= "none" and kind ~= nil then return end -- (battlegrounds, arenas...)
  if Scrambled(map, zone) then -- (in the world only: dungeons reset in a row are new copies)
    Hide()
    return
  end
  local layers = Saved()
  if not (layers and realm) then return end
  layers[realm] = layers[realm] or {}
  local copies = layers[realm][map] or {}
  layers[realm][map] = copies
  copies[zone] = Now()
  current.map, current.zone = map, zone
  return map, zone
end

-- What can be seen now: the target, the mouseover, the nameplates (all in one copy: three at once are none)
local function Look()
  local now = {}
  local function See(unit)
    local map, zone = Seen(unit)
    if map and zone then
      now[map] = now[map] or {}
      now[map][zone] = true
    end
  end
  See("target")
  See("mouseover")
  if C_NamePlate and C_NamePlate.GetNamePlates then
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
      local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
      if unit then See(unit) end
    end
  end
  for _, zones in pairs(now) do
    local n = 0
    for _ in pairs(zones) do n = n + 1 end
    if n >= 3 and not hidden then Hide() end
  end
end

-- The layer you are on, by its order among the ones seen on this continent; nil if not known
function ns.Layer()
  if hidden then return end
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
  elseif hidden and (kind == "none" or kind == nil) then
    GameTooltip:AddLine(L.LAYER_HIDDEN, .6, .6, .6)
  elseif kind == "none" or kind == nil then
    GameTooltip:AddLine(L.LAYER_UNKNOWN, .6, .6, .6)
  end
end

-- In the tooltip of the portrait menu's "Reset all instances": the entries of the hour and of the day
local function InstanceLines(tooltip)
  if not ns.sv then return end
  tooltip:SetText(RESET_INSTANCES or "")
  local hour, day, frees = ns.InstanceCounts()
  local color = hour >= PER_HOUR and RED_FONT_COLOR or NORMAL_FONT_COLOR
  local text = L.INSTANCES_HOUR:format(hour, PER_HOUR)
  if hour > 0 and frees then text = text .. " " .. L.INSTANCES_FREES:format(math.max(1, floor(frees / 60 + .5))) end
  tooltip:AddLine(text, color.r, color.g, color.b)
  local dayColor = day >= PER_DAY and RED_FONT_COLOR or NORMAL_FONT_COLOR
  tooltip:AddLine(L.INSTANCES_DAY:format(day, PER_DAY), dayColor.r, dayColor.g, dayColor.b)
end
-- (called by the portrait menu's own changes, Core.lua)
function ns.TipResetInstances(root)
  if not (RESET_INSTANCES and MenuUtil.GetElementText) then return end
  for _, description in root:EnumerateElementDescriptions() do
    if MenuUtil.GetElementText(description) == RESET_INSTANCES then
      if description.SetTooltip then description:SetTooltip(InstanceLines) end
      return
    end
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    realm = GetRealmName and GetRealmName() or "?"
    me = (UnitName("player") or "?") .. "-" .. realm
    Saved()
    if ns.sv and ns.sv.layerHidden ~= nil then
      if ns.sv.layerHidden == Build() then hidden = true else ns.sv.layerHidden = nil end -- (a new build: looked at again)
    end
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
