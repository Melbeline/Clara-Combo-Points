-- Clara Combo Points - boxes over the target and focus frames, in the look of the threat percent
-- (Era's box, which the game's own frames use too: its border, its colored fill, its number), side
-- by side over the name bar, from left to right:
--   the unit's attack speed, live ("1.2s"; WeaponSwingTimer's frames tab, a hunter's by default):
--   against an NPC, orange when it is 1.2 s or faster, dark yellow when slower than 2 s, pulsing or
--   flashing the first seconds (a tamed beast keeps its speed, and its damage with it);
--   the threat percent in a fight, as the game reads it (your share of the unit's threat, or your
--   lead while it attacks you), in the threat color; the game shows its own only with the
--   threatShowNumeric setting, hidden while this one shows; a box in the game's options
--   (Esc > Options > AddOns > Clara Combo Points) turns it off;
--   the distance to an enemy, from WeaponSwingTimer's range bands ("8-15 m"), in their colors (a
--   hunter's by default).
-- Centered over the name bar, never past its right end (the portrait is there); the longer box
-- drawn with the same border, its ends as drawn and its straight middle stretched.
-- And a boss's swing timer: a mark crossing its name bar from one swing to the next, before or
-- behind the name. The combat log is closed to addons: its swings are the hits seen on its target
-- (you, your pet, your group or raid), their pace its attack speed (else the time between two).
-- None of the WeaponSwingTimer parts while that module is not built in. On ClassicUI's frames, the
-- boxes in its art beside its own threat percent (Modules/ClassicUI/Units/ClaraUnitBoxes.lua).

local ADDON, ns = ...
local L = ns.L

local BOX_W, BOX_H, FILL_W, FILL_H, FILL_Y, TEXT_Y = 49, 18, 37, 14, -3, -4 -- (the game's own)
local WIDTH = { speed = BOX_W, threat = BOX_W, range = 60 }
local GAP = 4
local TEX_W = 64 -- (the border's file; its ends 9 wide, its straight middle from 9 to 40)
local END_W = 9
local BORDER = "Interface\\TargetingFrame\\NumericThreatBorder"
local FILL = "Interface\\TargetingFrame\\UI-StatusBar"
local BORDER_COORDS = { 0, 0.765625, 0, 0.5625 }
local TICK = 0.2 -- the attack speed and the distance read again
local FRAMES = { target = "TargetFrame", focus = "FocusFrame" }
local UNITS = { "target", "focus" }
local SPEED_COLORS = { normal = { .5, .5, .5 }, fast = { 1, .5, 0 }, slow = { .72, .58, 0 } }
local PULSE = 1      -- seconds a pulse (fast)
local BLINK = .25    -- seconds on, then off (slow)
local MELEE = { WOUND = true, DODGE = true, PARRY = true, MISS = true, BLOCK = true } -- (a swing's outcomes)
local SWING_MIN, SWING_MAX = .4, 5 -- the plausible time between two swings
local MARK_W = 3

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Yes(v) return not Secret(v) and v and true or false end

function ns:ThreatBox() return not self.sv or self.sv.threatBox ~= false end

---------------------------------------------------------------------------
-- The boxes
---------------------------------------------------------------------------
-- The game's pieces of a frame: its name bar, its name, where its own threat box sits
local function Parts(unit)
  local frame = _G[FRAMES[unit]]
  local content = frame and frame.TargetFrameContent
  local main = content and content.TargetFrameContentMain
  local contextual = content and content.TargetFrameContentContextual
  if not (main and main.ReputationColor and contextual) then return nil end
  return main.ReputationColor, contextual, main
end

-- The threat box as the game draws it; longer: its border in three (ends, middle stretched)
local function NewBox(parent, width)
  local box = CreateFrame("Frame", nil, parent)
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

-- Over the fill, for the pulse and the flash: the same bar, added
local function Glow(box)
  if box.glow then return box.glow end
  box.glow = box:CreateTexture(nil, "BORDER")
  box.glow:SetTexture(FILL)
  box.glow:SetBlendMode("ADD")
  box.glow:SetAllPoints(box.fill)
  box.glow:SetAlpha(0)
  return box.glow
end

local function SetShown(box, show)
  if box and box:IsShown() ~= show then box:SetShown(show) end
end

-- WeaponSwingTimer, when built in
local function WST() return ns.WST end
local function RangeOn() local w = WST(); return w ~= nil and w.RangeBand ~= nil and w.RangeBoxOn and w.RangeBoxOn() or false end
local function SpeedOn() local w = WST(); return w ~= nil and w.SpeedBoxOn ~= nil and w.SpeedBoxOn() or false end

-- Where a frame's boxes go: over the game's name bar (spot.base), or ClassicUI's frame (its art,
-- its own threat box); the boxes made the first time each is wanted
local spots, lastSpot = {}, {}
local function Spot(unit)
  local cui = ns.ClassicUIPrivate
  local spot = cui and cui.ClaraClassicSpot and cui.ClaraClassicSpot(unit)
  if not spot then
    local bar, contextual, main = Parts(unit)
    if not bar then return nil end
    spot = spots[unit]
    if not spot then
      spot = { base = true, anchor = bar, bar = bar, main = main, x = 0, y = 0, parent = contextual,
        game = contextual.NumericalThreat, boxes = {} }
      spots[unit] = spot
    end
    spot.width = bar:GetWidth() or 0
  end
  if lastSpot[unit] and lastSpot[unit] ~= spot then -- (ClassicUI's frames turned on or off)
    for kind, box in pairs(lastSpot[unit].boxes) do if kind ~= "threat" or lastSpot[unit].base then SetShown(box, false) end end
  end
  lastSpot[unit] = spot
  return spot
end

local function Box(spot, kind)
  if kind == "threat" and not spot.base then return spot.threat end -- (ClassicUI's own)
  local box = spot.boxes[kind]
  if not box then
    box = spot.base and NewBox(spot.parent, WIDTH[kind]) or spot.Make(WIDTH[kind])
    spot.boxes[kind] = box
  end
  return box
end

-- Side by side, centered over the name bar, never past its right end: placed again only when the
-- boxes wanted change
local function Layout(spot)
  local wanted = { speed = SpeedOn(), threat = spot.base and ns:ThreatBox() or (not spot.base and spot.threatOn),
    range = RangeOn() }
  local list = {}
  for _, kind in ipairs({ "speed", "threat", "range" }) do
    if wanted[kind] and Box(spot, kind) then list[#list + 1] = kind end
  end
  local key = table.concat(list, "/") .. ":" .. tostring(spot.width) .. ":" .. tostring(spot.threat)
  if spot.placed == key then return end
  spot.placed = key
  local total = -GAP
  for _, kind in ipairs(list) do total = total + WIDTH[kind] + GAP end
  local left = spot.x - total / 2
  local right = spot.x + spot.width / 2
  if left + total > right then left = right - total end
  for _, kind in ipairs(list) do
    local box = Box(spot, kind)
    if spot.base or kind ~= "threat" then box:ClearAllPoints() end
    box:SetPoint("BOTTOM", spot.anchor, "TOP", left + WIDTH[kind] / 2, spot.y)
    left = left + WIDTH[kind] + GAP
  end
end

---------------------------------------------------------------------------
-- The threat percent (the game's reading, UnitFrame_UpdateThreatIndicator)
---------------------------------------------------------------------------
local function Threat(unit)
  if not (UnitExists(unit) and not Yes(UnitIsDead(unit)) and UnitClassification(unit) ~= "minus") then return nil end
  if not (UnitDetailedThreatSituation and GetThreatStatusColor) then return nil end
  local tanking, status, _, raw = UnitDetailedThreatSituation("player", unit)
  local value = raw
  if tanking and not Secret(tanking) and UnitThreatPercentageOfLead then value = UnitThreatPercentageOfLead("player", unit) end
  if value == nil or status == nil or Secret(value) or Secret(status) or value == 0 then return nil end
  return value, status
end

local gameFaded = {}
local function UpdateThreat(unit)
  local spot = Spot(unit)
  if not (spot and spot.base) then return end -- (ClassicUI's frame: its own threat percent)
  Layout(spot)
  local on = ns:ThreatBox()
  -- the game's own box out of sight while ours is on (both in the same place)
  local game = spot.game
  if game and (on or gameFaded[unit]) then
    gameFaded[unit] = on or nil
    game:SetAlpha(on and 0 or 1)
  end
  local threat = spot.boxes.threat
  if not threat then return end
  local value, status = nil, nil
  if on then value, status = Threat(unit) end
  if value then
    threat.text:SetFormattedText("%1.0f%%", value)
    threat.fill:SetVertexColor(GetThreatStatusColor(status))
  end
  SetShown(threat, value ~= nil)
end

---------------------------------------------------------------------------
-- The attack speed: its color against an NPC, a pulse (fast) or a flash (slow) the first seconds
-- of a new unit or speed
---------------------------------------------------------------------------
local function Seconds(speed)
  local text = string.format("%.2f", speed)
  if text:sub(-1) == "0" then text = text:sub(1, -2) end -- ("1.20": "1.2"; "2.00": "2.0")
  return text .. L.SPEED_UNIT
end

local function Attackable(unit)
  return UnitExists(unit) and not Yes(UnitIsDead(unit)) and Yes(UnitCanAttack("player", unit))
end

local function SpeedOf(unit)
  if not (UnitAttackSpeed and Attackable(unit)) then return nil end
  local speed = UnitAttackSpeed(unit)
  if speed == nil or Secret(speed) or type(speed) ~= "number" or speed <= 0 then return nil end
  return speed
end

-- An NPC: not a player, nor a player's pet (no colors nor flashes against them)
local function Npc(unit)
  local player, controlled = UnitIsPlayer and UnitIsPlayer(unit), UnitPlayerControlled and UnitPlayerControlled(unit)
  if Secret(player) or Secret(controlled) then return false end
  return not player and not controlled
end

local function Animate(box)
  local a = box.anim
  local t = GetTime() - a.since
  if t >= a.duration then
    box.glow:SetAlpha(0)
    box.anim = nil
    box:SetScript("OnUpdate", nil)
    return
  end
  if a.kind == "fast" then
    box.glow:SetAlpha(.5 * (.5 - .5 * math.cos(t * 2 * math.pi / PULSE)))
  else
    box.glow:SetAlpha(math.floor(t / BLINK) % 2 == 0 and .55 or 0)
  end
end

local picked = { target = 0, focus = 0 } -- (a new target or focus: counted)
local seen = {}                          -- [unit] = { picked, kind, since }
local function UpdateSpeed(unit, spot)
  local wst = WST()
  local box = spot.boxes.speed
  local speed = wst and SpeedOn() and SpeedOf(unit)
  if not (box and speed) then
    if box then SetShown(box, false) end
    seen[unit] = nil
    return
  end
  local kind = "normal"
  local npc = Npc(unit)
  if npc and speed <= wst.SPEED_FAST + .005 then kind = "fast" elseif npc and speed > wst.SPEED_SLOW + .005 then kind = "slow" end
  local text = Seconds(speed)
  if box.value ~= text then box.value = text; box.text:SetText(text) end
  local c = SPEED_COLORS[kind]
  box.fill:SetVertexColor(c[1], c[2], c[3])
  local s = seen[unit]
  if not s or s.picked ~= picked[unit] or s.kind ~= kind then
    s = { picked = picked[unit], kind = kind, since = GetTime() }
    seen[unit] = s
    local flash, duration = wst.SpeedFlash()
    local glow = Glow(box)
    if flash and kind ~= "normal" and duration > 0 then
      box.anim = { kind = kind, since = s.since, duration = duration }
      box:SetScript("OnUpdate", Animate)
    else
      box.anim = nil
      box:SetScript("OnUpdate", nil)
      glow:SetAlpha(0)
    end
  end
  SetShown(box, true)
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

local function UpdateRange(unit, spot)
  local box = spot.boxes.range
  local wst = WST()
  local short, key, r, g, b
  if box and RangeOn() and UnitExists(unit) then short, key, r, g, b = wst.RangeBand(unit) end
  if short then
    Label(box, short)
    box.fill:SetVertexColor(r or .65, g or .65, b or .65)
  end
  if box then SetShown(box, short ~= nil) end
end

-- Over ClassicUI's frame: the name steps up while a box shows there
local function Told(spot)
  if spot.base or not spot.Shown then return end
  local any = false
  for kind, box in pairs(spot.boxes) do if box:IsShown() then any = true end end
  spot.Shown(any)
end

-- Both, read again; true while the unit is there to be read again
local function UpdateBoxes(unit)
  local spot = Spot(unit)
  if not spot then return false end
  Layout(spot)
  UpdateSpeed(unit, spot)
  UpdateRange(unit, spot)
  Told(spot)
  return UnitExists(unit) and (SpeedOn() or RangeOn())
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
    if UpdateBoxes(unit) then watching = true end
  end
  if not watching then self:Hide() end -- (nothing to read: woken by a new target or focus)
end)

local function Wake()
  wait = 0
  driver:Show()
end

---------------------------------------------------------------------------
-- A boss's swing timer: a mark across its name bar
---------------------------------------------------------------------------
local swings = {} -- [unit] = { boss, last (a swing seen), interval (between the last two) }
local marks = {}  -- [unit] = the mark
local boss = { on = true, r = 1, g = 1, b = 1, a = .9, front = true }

local function IsBoss(unit)
  if not UnitExists(unit) or Yes(UnitIsDead(unit)) then return false end
  local class = UnitClassification(unit)
  if not Secret(class) and class == "worldboss" then return true end
  local level = UnitLevel and UnitLevel(unit)
  if not Secret(level) and level == -1 then return true end
  for i = 1, 5 do
    if UnitExists("boss" .. i) and Yes(UnitIsUnit(unit, "boss" .. i)) then return true end
  end
  return false
end

-- Its pace: its attack speed, else the time between the last two swings seen
local function Pace(unit, s)
  local speed = UnitAttackSpeed and UnitAttackSpeed(unit)
  if speed ~= nil and not Secret(speed) and type(speed) == "number" and speed > 0 then return speed end
  return s.interval
end

-- The mark on the name's own frame (behind the name, or before it), the height of the name bar
local function Mark(unit)
  local bar, _, main = Parts(unit)
  if not bar then return nil end
  local host = (main.Name and main.Name:GetParent()) or main
  local mark = marks[unit]
  if not mark or mark.host ~= host then
    if mark then mark:Hide() end
    mark = host:CreateTexture(nil, "OVERLAY")
    mark.host, mark.bar = host, bar
    marks[unit] = mark
  end
  mark:SetDrawLayer(boss.front and "OVERLAY" or "ARTWORK", 7)
  mark:SetColorTexture(boss.r, boss.g, boss.b, 1)
  mark:SetAlpha(boss.a)
  mark:SetSize(MARK_W, math.max(1, bar:GetHeight() or 1))
  return mark
end

local swingDriver = CreateFrame("Frame")
swingDriver:Hide()
swingDriver:SetScript("OnUpdate", function(self)
  local now, any = GetTime(), false
  for _, unit in ipairs(UNITS) do
    local s, mark = swings[unit], marks[unit]
    local pace = s and s.boss and s.last and boss.on and Pace(unit, s)
    local show = false
    if pace and mark then
      local done = (now - s.last) / pace
      if done <= 1.5 then -- (past it: no swing seen since, gone till the next)
        show = true
        mark:ClearAllPoints()
        mark:SetPoint("CENTER", mark.bar, "LEFT", math.min(done, 1) * (mark.bar:GetWidth() or 0), 0)
      end
    end
    SetShown(mark, show)
    any = any or show
  end
  if not any then self:Hide() end
end)

-- A hit on a boss's target: its swing
local function Swung(victim, action, school)
  if not MELEE[action] or (action == "WOUND" and school ~= 1) or Secret(victim) then return end
  local now = GetTime()
  for _, unit in ipairs(UNITS) do
    local s = swings[unit]
    if s and s.boss and Yes(UnitIsUnit(victim, unit .. "target")) then
      if s.last then
        local gap = now - s.last
        if gap >= SWING_MIN and gap <= SWING_MAX then s.interval = gap end
      end
      s.last = now
      if Mark(unit) then swingDriver:Show() end
    end
  end
end

local events = CreateFrame("Frame")

-- A new target or focus: is it a boss (the hits are then watched)
local function WatchSwings()
  local watching = false
  for _, unit in ipairs(UNITS) do
    local s = swings[unit]
    if s and s.boss and boss.on then watching = true end
  end
  if watching then events:RegisterEvent("UNIT_COMBAT") else events:UnregisterEvent("UNIT_COMBAT") end
  for _, unit in ipairs(UNITS) do
    local mark = marks[unit]
    if mark and swings[unit] and swings[unit].boss then Mark(unit) end -- (its settings)
    if mark and not (boss.on and swings[unit] and swings[unit].boss) then mark:Hide() end
  end
end

local function NewUnit(unit)
  picked[unit] = picked[unit] + 1
  swings[unit] = { boss = IsBoss(unit) }
  if marks[unit] then marks[unit]:Hide() end
end

---------------------------------------------------------------------------
-- Everything again: a new target or focus, a setting changed
---------------------------------------------------------------------------
local function Refresh()
  local wst = WST()
  if wst and wst.BossSwing then
    boss.on, boss.r, boss.g, boss.b, boss.a, boss.front = wst.BossSwing()
  else
    boss.on = false
  end
  for _, unit in ipairs(UNITS) do
    UpdateThreat(unit)
    UpdateBoxes(unit)
  end
  WatchSwings()
  Wake()
end
ns.RefreshUnitBoxes = Refresh

function ns:SetThreatBox(on)
  if on then self.sv.threatBox = nil else self.sv.threatBox = false end
  Refresh()
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, action, _, _, school)
  if event == "UNIT_COMBAT" then
    Swung(unit, action, school)
  elseif event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    if not (_G.TargetFrame or _G.FocusFrame) then return end
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
      self:RegisterEvent(e)
    end
    pcall(self.RegisterUnitEvent, self, "UNIT_THREAT_LIST_UPDATE", "target", "focus")
    pcall(self.RegisterUnitEvent, self, "UNIT_THREAT_SITUATION_UPDATE", "player", "target") -- (the player's standing)
    if ns.WST then ns.WST.OnRangeBoxChanged = Refresh end -- (its settings changed)
    for _, u in ipairs(UNITS) do NewUnit(u) end
    Refresh()
  elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
    UpdateThreat("target")
    UpdateThreat("focus")
  else
    if event == "PLAYER_TARGET_CHANGED" then NewUnit("target")
    elseif event == "PLAYER_FOCUS_CHANGED" then NewUnit("focus")
    elseif event == "PLAYER_ENTERING_WORLD" then NewUnit("target"); NewUnit("focus") end
    Refresh()
  end
end)
