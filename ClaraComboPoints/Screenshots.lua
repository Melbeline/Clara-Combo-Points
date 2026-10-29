-- Clara Combo Points - screenshots of a character's milestones, taken a moment after (the game's own
-- Screenshot, as its key): each level gained, and the first kill, for this character, of a raid boss,
-- of a boss of a dungeon at level 54 or more, and of a leveling dungeon's last boss (later kills of
-- the same boss: none). The level one is left to Leatrix Plus (Cheese's) when that one is on, or to
-- Cheese itself. Two boxes in the game's options turn either off.

local ADDON, ns = ...

local HIGH = 54          -- a dungeon of this level: every boss counts
-- The last boss of each leveling dungeon (NPC ID), whatever the game's language
local LAST = {
  [11520] = true, -- Ragefire Chasm: Taragaman the Hungerer
  [3654] = true,  -- Wailing Caverns: Mutanus the Devourer
  [639] = true,   -- The Deadmines: Edwin VanCleef
  [4275] = true,  -- Shadowfang Keep: Archmage Arugal
  [4829] = true,  -- Blackfathom Deeps: Aku'mai
  [1716] = true,  -- The Stockade: Bazil Thredd
  [7800] = true,  -- Gnomeregan: Mekgineer Thermaplugg
  [4421] = true,  -- Razorfen Kraul: Charlga Razorflank
  [4543] = true,  -- Scarlet Monastery, Graveyard: Bloodmage Thalnos
  [6487] = true,  -- Library: Arcanist Doan
  [3975] = true,  -- Armory: Herod
  [3977] = true,  -- Cathedral: High Inquisitor Whitemane
  [7358] = true,  -- Razorfen Downs: Amnennar the Coldbringer
  [2748] = true,  -- Uldaman: Archaedas
  [7267] = true,  -- Zul'Farrak: Chief Ukorz Sandscalp
  [12201] = true, -- Maraudon: Princess Theradras
  [5709] = true,  -- Sunken Temple: Shade of Eranikus
  [9019] = true,  -- Blackrock Depths: Emperor Dagran Thaurissan
}

function ns:LevelShots() return not (self.sv and self.sv.levelShots == false) end
function ns:BossShots() return not (self.sv and self.sv.bossShots == false) end
function ns:SetLevelShots(on) if on then self.sv.levelShots = nil else self.sv.levelShots = false end end
function ns:SetBossShots(on) if on then self.sv.bossShots = nil else self.sv.bossShots = false end end

local issecret = issecretvalue or function() return false end

local function Shoot()
  C_Timer.After(1, function() if Screenshot then Screenshot() end end)
end

-- Leatrix Plus's own level shot (Cheese's), built in or its own addon, or Cheese itself
local function TheirsOn()
  local A = C_AddOns
  if A and A.IsAddOnLoaded and A.IsAddOnLoaded("Cheese") then return true end
  if ns.QolState and ns:QolState("leatrix") == "on" then
    return type(ClaraLeaPlusDB) == "table" and ClaraLeaPlusDB.LevelUpScreenshot == "On"
  end
  return A and A.IsAddOnLoaded and A.IsAddOnLoaded("Leatrix_Plus") and type(LeaPlusDB) == "table"
    and LeaPlusDB.LevelUpScreenshot == "On" or false
end

-- This character's bosses already shot
local function Killed()
  local sv = ns.sv
  local me = UnitGUID("player")
  if not sv or not me or issecret(me) then return end
  sv.bossKills = sv.bossKills or {}
  sv.bossKills[me] = sv.bossKills[me] or {}
  return sv.bossKills[me]
end

local function First(key)
  local killed = Killed()
  if not killed or killed[key] then return false end
  killed[key] = time()
  return true
end

local function NpcID(unit)
  local guid = UnitGUID(unit)
  if not guid or issecret(guid) then return end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- The bosses of the fight on: their highest level (-1: a skull) and their IDs
local fight
local function Bosses()
  if not fight then return end
  for i = 1, 5 do
    local unit = "boss" .. i
    if UnitExists(unit) then
      local level, id = UnitLevel(unit), NpcID(unit)
      if not issecret(level) and level then
        if level < 0 then level = 99 end
        if level > fight.level then fight.level = level end
      end
      if id then fight.ids[id] = true end
    end
  end
end

local function Kind()
  local _, kind = GetInstanceInfo()
  return kind
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
  if event == "PLAYER_LEVEL_UP" then
    if ns:LevelShots() and not TheirsOn() then Shoot() end
  elseif event == "ENCOUNTER_START" then
    fight = { level = 0, ids = {} }
    Bosses()
  elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
    Bosses()
  elseif event == "ENCOUNTER_END" then
    Bosses()
    local done = fight
    fight = nil
    if a5 ~= 1 or not ns:BossShots() or type(a1) ~= "number" then return end
    local kind = Kind()
    local last = false
    for id in pairs(done and done.ids or {}) do if LAST[id] then last = true end end
    if kind == "raid" or (kind == "party" and (last or (done and done.level >= HIGH))) then
      if First("e" .. a1) then Shoot() end
      for id in pairs(done and done.ids or {}) do First("n" .. id) end -- (not again by the watch below)
    end
  elseif event == "UNIT_HEALTH" or event == "PLAYER_TARGET_CHANGED" then
    -- a leveling dungeon's last boss with no encounter of the game's: seen dead
    local unit = event == "PLAYER_TARGET_CHANGED" and "target" or a1
    if fight or type(unit) ~= "string" or issecret(unit) or not (unit == "target" or unit:find("^nameplate")) then return end
    local dead = UnitIsDead(unit)
    if dead ~= true or issecret(dead) or not ns:BossShots() then return end
    local id = NpcID(unit)
    if id and LAST[id] and First("n" .. id) then Shoot() end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    -- the dead-boss watch, in a dungeon only
    local inside = Kind() == "party"
    for _, e in ipairs({ "UNIT_HEALTH", "PLAYER_TARGET_CHANGED" }) do
      if inside then events:RegisterEvent(e) else events:UnregisterEvent(e) end
    end
  end
end)

for _, event in ipairs({ "PLAYER_LEVEL_UP", "ENCOUNTER_START", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "ENCOUNTER_END",
  "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
  pcall(events.RegisterEvent, events, event)
end
