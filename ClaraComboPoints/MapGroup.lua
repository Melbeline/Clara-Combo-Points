-- Clara Combo Points - the group's and the raid's members above everything on the world map. The game draws them on
-- one layer of its map (GroupMembersPinTemplate) at its own place in the map's order, under what other addons put on
-- the map at a fixed height (Questie's quest icons: from 2016 up), so a member under a quest's icons could hardly be
-- seen. That layer is set above all the map holds (its highest frame level, plus one, kept as the map changes), in the
-- map's own strata: above every icon on the map, never above another window over the map. The layer takes no mouse
-- (the game finds the member under the mouse by itself), so the icons under it keep their tooltips and clicks. On the
-- world map and the zone map (Shift+M). Not in a fight while the game counts the layer protected (then just after).
-- Their size as in WoW Classic 1.15.9: 16 for the group and the raid (Classic Era's GroupMembersDataProvider), where
-- WoW Forever draws them 11 and 8 (the retail sizes); set just after the game sets its own (at each zoom), the game's
-- table of sizes untouched.
-- The minimap: the game draws the members' dots inside the minimap's own drawing, under every icon an addon puts on
-- it (Questie's, through HereBeDragons, from 2016 up), and nothing lets an addon raise them. So a dot of Clara's is put
-- on each member there (in their class's color, the game's dot's size), by HereBeDragons as it puts Questie's, above
-- every icon of the minimap; gone when the member leaves, is out of reach (the minimap's edge) or out of the world.
-- Only with HereBeDragons loaded (Questie, GatherMate, TomTom...): without it nothing covers the game's dots. No mouse
-- on them (the game's tooltip of the dot under the mouse stays).
-- On by default; its box on Clara's page.

local ADDON, ns = ...

local TEMPLATE = "GroupMembersPinTemplate"
local issecret = issecretvalue or function() return false end
local function Plain(v) return v ~= nil and not issecret(v) end
local FLOOR, CEILING = 2500, 9990 -- (never under Questie's icons, never past the game's highest level)
local MEMBER_SIZE = 16 -- (Classic 1.15.9's, for the group and the raid; the player's arrow left as the game draws it)

function ns:MapGroupOnTop() return not self.sv or self.sv.mapGroupOnTop ~= false end

local hooked = setmetatable({}, { __mode = "k" })
local pending = false

-- The map's highest frame level, its group layer left out
local function Highest(canvas, skip)
  local top = 0
  for _, child in ipairs({ canvas:GetChildren() }) do
    if child ~= skip and child.GetFrameLevel then
      local level = child:GetFrameLevel()
      if type(level) == "number" and level > top then top = level end
    end
  end
  return top
end

local function Raise(pin)
  if not ns:MapGroupOnTop() or not pin or not pin.GetMap then return end
  if InCombatLockdown() and pin.IsProtected and pin:IsProtected() then pending = true return end
  local map = pin:GetMap()
  local canvas = map and map.GetCanvas and map:GetCanvas()
  if not canvas then return end
  local level = math.min(CEILING, math.max(FLOOR, Highest(canvas, pin) + 1))
  if pin:GetFrameLevel() ~= level then
    if pin.SetFixedFrameLevel then pin:SetFixedFrameLevel(false) end
    pin:SetFrameLevel(level)
    if pin.SetFixedFrameLevel then pin:SetFixedFrameLevel(true) end -- (its parent's level changing: kept)
  end
end

-- The members' size as in Classic 1.15.9, after the game's own (its zoom taken into account as it does)
local function Size(pin)
  if not ns:MapGroupOnTop() or not (pin and pin.SetPinSize and pin.GetMap) then return end
  if InCombatLockdown() and pin.IsProtected and pin:IsProtected() then pending = true return end
  local map = pin:GetMap()
  local scale = map and map.GetCanvasScale and map:GetCanvasScale()
  if type(scale) ~= "number" or scale <= 0 then return end
  for _, unit in ipairs({ "party", "raid" }) do pcall(pin.SetPinSize, pin, unit, MEMBER_SIZE / scale) end
end

-- Back to the game's own place and sizes (the box unticked)
local function Lower(pin)
  if InCombatLockdown() and pin.IsProtected and pin:IsProtected() then pending = true return end
  if pin.SetFixedFrameLevel then pin:SetFixedFrameLevel(false) end
  if pin.ApplyFrameLevel then pin:ApplyFrameLevel() end
  if pin.SynchronizePinSizes then pcall(pin.SynchronizePinSizes, pin) end
end

local function EachPin(map, fn)
  if not (map and map.EnumeratePinsByTemplate) then return end
  for pin in map:EnumeratePinsByTemplate(TEMPLATE) do fn(pin) end
end

local function Watch(map)
  EachPin(map, function(pin)
    if not hooked[pin] and pin.ApplyFrameLevel then
      hooked[pin] = true
      hooksecurefunc(pin, "ApplyFrameLevel", Raise) -- (the game setting its place again: raised again)
      if pin.SynchronizePinSizes then hooksecurefunc(pin, "SynchronizePinSizes", Size) end -- (its sizes, at each zoom)
    end
    Raise(pin)
    Size(pin)
  end)
end

local function Maps() return { WorldMapFrame, BattlefieldMapFrame } end

-- Each time a map is shown or changes (another zone, a zoom): looked at a moment later, once what it shows is there
local function Soon(map)
  if not map then return end
  C_Timer.After(0.1, function() if map:IsShown() then Watch(map) end end)
end

local function HookMap(map)
  if not map or hooked[map] then return end
  hooked[map] = true
  map:HookScript("OnShow", function(self) Soon(self) end)
  if map.OnMapChanged then hooksecurefunc(map, "OnMapChanged", Soon) end
  if map.RefreshAllDataProviders then hooksecurefunc(map, "RefreshAllDataProviders", Soon) end
  if map:IsShown() then Soon(map) end
end

---------------------------------------------------------------------------
-- The minimap's dots
---------------------------------------------------------------------------
local REF, DOT, EVERY = "ClaraMapGroup", 12, 0.2
local HBD, Pins
local dots, placed = {}, {} -- (unit: its dot; its last place given, not given again while the same)
local level, levelAt = FLOOR + 100, -100

local function Libs()
  if not LibStub then return false end
  HBD = HBD or LibStub("HereBeDragons-2.0", true)
  Pins = Pins or LibStub("HereBeDragons-Pins-2.0", true)
  return HBD ~= nil and Pins ~= nil
end

local function Dot(unit)
  local dot = dots[unit]
  if dot then return dot end
  dot = CreateFrame("Frame", nil, Minimap)
  dot:SetSize(DOT, DOT)
  dot:EnableMouse(false)
  dot.edge = dot:CreateTexture(nil, "ARTWORK")
  dot.edge:SetAllPoints()
  dot.edge:SetTexture("Interface\\COMMON\\Indicator-Gray")
  dot.edge:SetVertexColor(0, 0, 0, 1)
  dot.fill = dot:CreateTexture(nil, "OVERLAY")
  dot.fill:SetPoint("CENTER")
  dot.fill:SetSize(DOT - 3, DOT - 3)
  dot.fill:SetTexture("Interface\\COMMON\\Indicator-Gray")
  dot:Hide()
  dots[unit] = dot
  return dot
end

local function Drop(unit)
  local dot = dots[unit]
  if not dot then return end
  if Pins and placed[unit] then pcall(Pins.RemoveMinimapIcon, Pins, REF, dot) end
  placed[unit] = nil
  dot:Hide()
end
local function DropAll() for unit in pairs(dots) do Drop(unit) end end

-- The level above every icon of the minimap (looked again every few seconds: icons come and go)
local function MinimapLevel()
  local now = GetTime()
  if now - levelAt >= 3 and Minimap then
    levelAt = now
    local top = 0
    for _, child in ipairs({ Minimap:GetChildren() }) do
      local isOurs = false
      for _, dot in pairs(dots) do if dot == child then isOurs = true break end end
      if not isOurs and child.GetFrameLevel then
        local l = child:GetFrameLevel()
        if type(l) == "number" and l > top then top = l end
      end
    end
    level = math.min(CEILING, math.max(FLOOR, top + 1))
  end
  return level
end

-- Where a member is: the world's coordinates (outside instances), else their place on the player's map
local function Where(unit)
  local ok, y, x, _, instance = pcall(UnitPosition, unit)
  if ok and Plain(x) and Plain(y) and Plain(instance) and type(x) == "number" then
    local ok2, wx, wy, winst = pcall(HBD.GetUnitWorldPosition, HBD, unit)
    if ok2 and type(wx) == "number" and type(wy) == "number" and type(winst) == "number" then return "world", winst, wx, wy end
  end
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not Plain(mapID) or not mapID or not C_Map.GetPlayerMapPosition then return nil end
  local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
  if not okPos or not pos or issecret(pos) or not pos.GetXY then return nil end
  local px, py = pos:GetXY()
  if not (Plain(px) and Plain(py)) or (px == 0 and py == 0) then return nil end
  return "map", mapID, px, py
end

local function Members()
  local list = {}
  if IsInRaid and IsInRaid() then
    for i = 1, MAX_RAID_MEMBERS or 40 do list[#list + 1] = "raid" .. i end
  elseif IsInGroup and IsInGroup() then
    for i = 1, MAX_PARTY_MEMBERS or 4 do list[#list + 1] = "party" .. i end
  end
  return list
end

local function UpdateDots()
  if not (ns:MapGroupOnTop() and Libs() and Minimap) then DropAll() return end
  local seen = {}
  local top = MinimapLevel()
  for _, unit in ipairs(Members()) do
    if UnitExists(unit) and not UnitIsUnit(unit, "player") and UnitIsConnected(unit) then
      local kind, where, x, y = Where(unit)
      if kind then
        seen[unit] = true
        local dot = Dot(unit)
        local _, class = UnitClass(unit)
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        dot.fill:SetVertexColor(c and c.r or 0.4, c and c.g or 0.6, c and c.b or 1, 1)
        local last = placed[unit]
        if not last or last.kind ~= kind or last.where ~= where or math.abs(last.x - x) > 1e-4 or math.abs(last.y - y) > 1e-4 then
          local ok
          if kind == "world" then
            ok = pcall(Pins.AddMinimapIconWorld, Pins, REF, dot, where, x, y, false)
          else
            ok = pcall(Pins.AddMinimapIconMap, Pins, REF, dot, where, x, y, true, false)
          end
          if ok then placed[unit] = { kind = kind, where = where, x = x, y = y } end
        end
        if dot:GetFrameLevel() ~= top then
          if dot.SetFixedFrameLevel then dot:SetFixedFrameLevel(false) end
          dot:SetFrameLevel(top)
          if dot.SetFixedFrameLevel then dot:SetFixedFrameLevel(true) end
        end
      end
    end
  end
  for unit in pairs(dots) do if not seen[unit] then Drop(unit) end end
end
ns.MapGroupDots = UpdateDots -- (for the tests)
ns.MapGroupDotOf = function(unit) return dots[unit] end -- (for the tests)

local ticker = CreateFrame("Frame")
local wait = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
  wait = wait - elapsed
  if wait > 0 then return end
  wait = EVERY
  UpdateDots()
end)
local function Ticking()
  local want = ns:MapGroupOnTop() and IsInGroup and IsInGroup()
  if want then ticker:Show() else ticker:Hide() DropAll() end
end
ticker:Hide()

function ns:SetMapGroupOnTop(on)
  if not self.sv then return end
  if on then self.sv.mapGroupOnTop = nil else self.sv.mapGroupOnTop = false end
  for _, map in ipairs(Maps()) do
    if map then EachPin(map, function(pin) if on then Raise(pin) Size(pin) else Lower(pin) end end) end
  end
  Ticking()
end
ns.MapGroupRaise = Raise -- (for the tests)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
  if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then Ticking() return end
  if event == "PLAYER_REGEN_ENABLED" then
    if pending then
      pending = false
      for _, map in ipairs(Maps()) do
        if map and map:IsShown() then EachPin(map, function(pin) if ns:MapGroupOnTop() then Raise(pin) Size(pin) else Lower(pin) end end) end
      end
    end
    return
  end
  HookMap(WorldMapFrame)
  HookMap(BattlefieldMapFrame)
  Ticking()
end)
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_BattlefieldMap", function() HookMap(BattlefieldMapFrame) end)
  EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", function() HookMap(WorldMapFrame) end)
end
