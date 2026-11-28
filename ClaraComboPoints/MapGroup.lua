-- Clara Combo Points - the group's and the raid's members above everything on the world map. The game draws them on
-- one layer of its map (GroupMembersPinTemplate) at its own place in the map's order, under what other addons put on
-- the map at a fixed height (Questie's quest icons: from 2016 up), so a member under a quest's icons could hardly be
-- seen. That layer is set above all the map holds (its highest frame level, plus one, kept as the map changes), in the
-- map's own strata: above every icon on the map, never above another window over the map. The layer takes no mouse
-- (the game finds the member under the mouse by itself), so the icons under it keep their tooltips and clicks. On the
-- world map and the zone map (Shift+M). Not in a fight while the game counts the layer protected (then just after).
-- On by default; its box on Clara's page.

local ADDON, ns = ...

local TEMPLATE = "GroupMembersPinTemplate"
local FLOOR, CEILING = 2500, 9990 -- (never under Questie's icons, never past the game's highest level)

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

-- Back to the game's own place (the box unticked)
local function Lower(pin)
  if InCombatLockdown() and pin.IsProtected and pin:IsProtected() then pending = true return end
  if pin.SetFixedFrameLevel then pin:SetFixedFrameLevel(false) end
  if pin.ApplyFrameLevel then pin:ApplyFrameLevel() end
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
    end
    Raise(pin)
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

function ns:SetMapGroupOnTop(on)
  if not self.sv then return end
  if on then self.sv.mapGroupOnTop = nil else self.sv.mapGroupOnTop = false end
  for _, map in ipairs(Maps()) do
    if map then EachPin(map, on and Raise or Lower) end
  end
end
ns.MapGroupRaise = Raise -- (for the tests)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if pending then
      pending = false
      for _, map in ipairs(Maps()) do
        if map and map:IsShown() then EachPin(map, ns:MapGroupOnTop() and Raise or Lower) end
      end
    end
    return
  end
  HookMap(WorldMapFrame)
  HookMap(BattlefieldMapFrame)
end)
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_BattlefieldMap", function() HookMap(BattlefieldMapFrame) end)
  EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", function() HookMap(WorldMapFrame) end)
end
